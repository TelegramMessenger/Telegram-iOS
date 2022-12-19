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

enum DrawingTextFont: Equatable, CaseIterable {
    case sanFrancisco
    case newYork
    case monospaced
    case round
    
    init(font: DrawingTextEntity.Font) {
        switch font {
        case .sanFrancisco:
            self = .sanFrancisco
        case .newYork:
            self = .newYork
        case .monospaced:
            self = .monospaced
        case .round:
            self = .round
        }
    }
    
    var font: DrawingTextEntity.Font {
        switch self {
        case .sanFrancisco:
            return .sanFrancisco
        case .newYork:
            return .newYork
        case .monospaced:
            return .monospaced
        case .round:
            return .round
        }
    }
    
    var title: String {
        switch self {
        case .sanFrancisco:
            return "San Francisco"
        case .newYork:
            return "New York"
        case .monospaced:
            return "Monospaced"
        case .round:
            return "Rounded"
        }
    }
    
    var uiFont: UIFont {
        switch self {
        case .sanFrancisco:
            return Font.semibold(13.0)
        case .newYork:
            return Font.with(size: 13.0, design: .serif, weight: .semibold)
        case .monospaced:
            return Font.with(size: 13.0, design: .monospace, weight: .semibold)
        case .round:
            return Font.with(size: 13.0, design: .round, weight: .semibold)
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
    let styleButton: AnyComponent<Empty>
    let alignmentButton: AnyComponent<Empty>
    
    let values: [DrawingTextFont]
    let selectedValue: DrawingTextFont
    let updated: (DrawingTextFont) -> Void
    
    init(styleButton: AnyComponent<Empty>, alignmentButton: AnyComponent<Empty>, values: [DrawingTextFont], selectedValue: DrawingTextFont, updated: @escaping (DrawingTextFont) -> Void) {
        self.styleButton = styleButton
        self.alignmentButton = alignmentButton
        self.values = values
        self.selectedValue = selectedValue
        self.updated = updated
    }
    
    static func == (lhs: TextFontComponent, rhs: TextFontComponent) -> Bool {
        return lhs.styleButton == rhs.styleButton && lhs.alignmentButton == rhs.alignmentButton && lhs.values == rhs.values && lhs.selectedValue == rhs.selectedValue
    }
    
    public final class View: UIView {
        private let styleButtonHost: ComponentView<Empty>
        private let alignmentButtonHost: ComponentView<Empty>
        
        private var buttons: [DrawingTextFont: HighlightableButton] = [:]
        private let scrollView = UIScrollView()
        private let scrollMask = UIView()
        private let maskLeft = SimpleGradientLayer()
        private let maskCenter = SimpleLayer()
        private let maskRight = SimpleGradientLayer()
        
        private var updated: (DrawingTextFont) -> Void = { _ in }
        
        override init(frame: CGRect) {
            if #available(iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.decelerationRate = .fast
            
            self.styleButtonHost = ComponentView()
            self.alignmentButtonHost = ComponentView()
            
            super.init(frame: frame)
            
            self.mask = self.scrollMask
            
            self.maskLeft.type = .axial
            self.maskLeft.startPoint = CGPoint(x: 0.0, y: 0.5)
            self.maskLeft.endPoint = CGPoint(x: 1.0, y: 0.5)
            self.maskLeft.colors = [UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.cgColor]
            self.maskLeft.locations = [0.0, 1.0]
            
            self.maskCenter.backgroundColor = UIColor.white.cgColor
            
            self.maskRight.type = .axial
            self.maskRight.startPoint = CGPoint(x: 0.0, y: 0.5)
            self.maskRight.endPoint = CGPoint(x: 1.0, y: 0.5)
            self.maskRight.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
            self.maskRight.locations = [0.0, 1.0]
            
            self.scrollMask.layer.addSublayer(self.maskLeft)
            self.scrollMask.layer.addSublayer(self.maskCenter)
            self.scrollMask.layer.addSublayer(self.maskRight)
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed(_ sender: HighlightableButton) {
            for (font, button) in self.buttons {
                if button === sender {
                    self.updated(font)
                    break
                }
            }
        }
        
        private var previousValue: DrawingTextFont?
        func update(component: TextFontComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.updated = component.updated
            
            var contentWidth: CGFloat = 10.0
            
            let styleSize = self.styleButtonHost.update(
                transition: transition,
                component: component.styleButton,
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.styleButtonHost.view {
                if view.superview == nil {
                    self.scrollView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: contentWidth - 7.0, y: -7.0), size: styleSize)
            }
            
            contentWidth += 44.0
            
            let alignmentSize = self.alignmentButtonHost.update(
                transition: transition,
                component: component.alignmentButton,
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.alignmentButtonHost.view {
                if view.superview == nil {
                    self.scrollView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: contentWidth - 7.0, y: -6.0 - UIScreenPixel), size: alignmentSize)
            }
            
            contentWidth += 36.0
            
            for value in component.values {
                contentWidth += 12.0
                let button: HighlightableButton
                if let current = self.buttons[value] {
                    button = current
                } else {
                    button = HighlightableButton()
                    button.setTitle(value.title, for: .normal)
                    button.titleLabel?.font = value.uiFont
                    button.sizeToFit()
                    button.frame = CGRect(origin: .zero, size: CGSize(width: button.frame.width + 16.0, height: 30.0))
                    button.layer.cornerRadius = 11.0
                    button.addTarget(self, action: #selector(self.pressed(_:)), for: .touchUpInside)
                    
                    self.buttons[value] = button
                    
                    self.scrollView.addSubview(button)
                }

                if value == component.selectedValue {
                    button.layer.borderWidth = 1.0 - UIScreenPixel
                    button.layer.borderColor = UIColor.white.cgColor
                } else {
                    button.layer.borderWidth = UIScreenPixel
                    button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
                }
                
                button.frame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: button.frame.size)
                contentWidth += button.frame.width
            }
            contentWidth += 12.0
            
            if self.scrollView.contentSize.width != contentWidth {
                self.scrollView.contentSize = CGSize(width: contentWidth, height: 30.0)
            }
            self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            
            self.scrollMask.frame = CGRect(origin: .zero, size: availableSize)
            self.maskLeft.frame = CGRect(origin: .zero, size: CGSize(width: 12.0, height: 30.0))
            self.maskCenter.frame = CGRect(origin: CGPoint(x: 12.0, y: 0.0), size: CGSize(width: availableSize.width - 24.0, height: 30.0))
            self.maskRight.frame = CGRect(origin: CGPoint(x: availableSize.width - 12.0, y: 0.0), size: CGSize(width: 12.0, height: 30.0))
            
            if component.selectedValue != self.previousValue {
                self.previousValue = component.selectedValue
                
                if let button = self.buttons[component.selectedValue] {
                    self.scrollView.scrollRectToVisible(button.frame.insetBy(dx: -48.0, dy: 0.0), animated: true)
                }
            }
            
            return availableSize
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
    let alignment: DrawingTextAlignment
    let font: DrawingTextFont
    let isEmojiKeyboard: Bool
    let tag: AnyObject?

    let presentColorPicker: () -> Void
    let presentFastColorPicker: (GenericComponentViewTag) -> Void
    let updateFastColorPickerPan: (CGPoint) -> Void
    let dismissFastColorPicker: () -> Void
    let toggleStyle: () -> Void
    let toggleAlignment: () -> Void
    let updateFont: (DrawingTextFont) -> Void
    let toggleKeyboard: (() -> Void)?
    
    init(
        color: DrawingColor?,
        style: DrawingTextStyle,
        alignment: DrawingTextAlignment,
        font: DrawingTextFont,
        isEmojiKeyboard: Bool,
        tag: AnyObject?,
        presentColorPicker: @escaping () -> Void = {},
        presentFastColorPicker: @escaping (GenericComponentViewTag) -> Void = { _ in },
        updateFastColorPickerPan: @escaping (CGPoint) -> Void = { _ in },
        dismissFastColorPicker: @escaping () -> Void = {},
        toggleStyle: @escaping () -> Void,
        toggleAlignment: @escaping () -> Void,
        updateFont: @escaping (DrawingTextFont) -> Void,
        toggleKeyboard: (() -> Void)?
    ) {
        self.color = color
        self.style = style
        self.alignment = alignment
        self.font = font
        self.isEmojiKeyboard = isEmojiKeyboard
        self.tag = tag
        self.presentColorPicker = presentColorPicker
        self.presentFastColorPicker = presentFastColorPicker
        self.updateFastColorPickerPan = updateFastColorPickerPan
        self.dismissFastColorPicker = dismissFastColorPicker
        self.toggleStyle = toggleStyle
        self.toggleAlignment = toggleAlignment
        self.updateFont = updateFont
        self.toggleKeyboard = toggleKeyboard
    }
    
    static func ==(lhs: TextSettingsComponent, rhs: TextSettingsComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.style != rhs.style {
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
    
    func makeState() -> State {
        State()
    }
    
    final class View: UIView, ComponentTaggedView {
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
    }
    
    func makeView() -> View {
        let view = View()
        view.componentTag = self.tag
        return view
    }
    
    static var body: Body {
        let colorButton = Child(ColorSwatchComponent.self)
        let colorButtonTag = GenericComponentViewTag()
        
        let keyboardButton = Child(Button.self)
        let font = Child(TextFontComponent.self)
        
        return { context in
            let component = context.component
            let state = context.state
            
            let toggleStyle = component.toggleStyle
            let toggleAlignment = component.toggleAlignment
            let updateFont = component.updateFont
            
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
                    .position(CGPoint(x: colorButton.size.width / 2.0, y: context.availableSize.height / 2.0))
                )
                offset += 32.0
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
                        
            let font = font.update(
                component: TextFontComponent(
                    styleButton: AnyComponent(
                        Button(
                            content: AnyComponent(
                                Image(
                                    image: styleImage
                                )
                            ),
                            action: {
                                toggleStyle()
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0))
                    ),
                    alignmentButton: AnyComponent(
                        Button(
                            content: AnyComponent(
                                TextAlignmentComponent(
                                    alignment: component.alignment
                                )
                            ),
                            action: {
                                toggleAlignment()
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0))
                    ),
                    values: DrawingTextFont.allCases,
                    selectedValue: component.font,
                    updated: { font in
                        updateFont(font)
                    }
                ),
                availableSize: CGSize(width: fontAvailableWidth, height: 30.0),
                transition: .easeInOut(duration: 0.2)
            )
            context.add(font
                .position(CGPoint(x: offset + font.size.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
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
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(keyboardButton
                    .position(CGPoint(x: context.availableSize.width - keyboardButton.size.width / 2.0, y: context.availableSize.height / 2.0))
                )
            }
                        
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
