import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import CheckNode
import AnimationUI

enum WallpaperOptionButtonValue {
    case check(Bool)
    case color(Bool, UIColor)
    case colors(Bool, [UIColor])
}

private func generateColorsImage(diameter: CGFloat, colors: [UIColor]) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))

        if !colors.isEmpty {
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            var startAngle = -CGFloat.pi * 0.5
            for i in 0 ..< colors.count {
                context.setFillColor(colors[i].cgColor)

                let endAngle = startAngle + 2.0 * CGFloat.pi * (1.0 / CGFloat(colors.count))

                context.move(to: center)
                context.addArc(center: center, radius: size.width / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.fillPath()

                startAngle = endAngle
            }
        }
    })
}

final class WallpaperLightButtonBackgroundNode: ASDisplayNode {
    private let backgroundNode: NavigationBackgroundNode
    private let overlayNode: ASDisplayNode
    private let lightNode: ASDisplayNode
    
    override init() {
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x333333, alpha: 0.35), enableBlur: true, enableSaturation: false)
        self.overlayNode = ASDisplayNode()
        self.overlayNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.75)
        self.overlayNode.layer.compositingFilter = "overlayBlendMode"
        
        self.lightNode = ASDisplayNode()
        self.lightNode.backgroundColor = UIColor(rgb: 0xf2f2f2, alpha: 0.2)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.overlayNode)
        self.addSubnode(self.lightNode)
    }
    
    func updateLayout(size: CGSize) {
        let frame = CGRect(origin: .zero, size: size)
        self.backgroundNode.frame = frame
        self.overlayNode.frame = frame
        self.lightNode.frame = frame
        
        self.backgroundNode.update(size: size, transition: .immediate)
    }
}

final class WallpaperOptionBackgroundNode: ASDisplayNode {
    private let backgroundNode: NavigationBackgroundNode
    
    var enableSaturation: Bool {
        didSet {
            self.backgroundNode.updateColor(color: UIColor(rgb: 0x333333, alpha: 0.35), enableBlur: true, enableSaturation: self.enableSaturation, transition: .immediate)
        }
    }
    
    init(enableSaturation: Bool = false) {
        self.enableSaturation = enableSaturation
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x333333, alpha: 0.35), enableBlur: true, enableSaturation: enableSaturation)

        super.init()
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
    }
    
    func updateLayout(size: CGSize) {
        let frame = CGRect(origin: .zero, size: size)
        self.backgroundNode.frame = frame
        
        self.backgroundNode.update(size: size, transition: .immediate)
    }
}

final class WallpaperNavigationButtonNode: HighlightTrackingButtonNode {
    enum Content {
        case icon(image: UIImage?, size: CGSize)
        case text(String)
        case dayNight(isNight: Bool)
    }
    
    var enableSaturation: Bool = false {
        didSet {
            if let backgroundNode = self.backgroundNode as? WallpaperOptionBackgroundNode {
                backgroundNode.enableSaturation = self.enableSaturation
            }
        }
    }
    
    private let content: Content
    var dark: Bool {
        didSet {
            if self.dark != oldValue {
                self.backgroundNode.removeFromSupernode()
                if self.dark {
                    self.backgroundNode = WallpaperOptionBackgroundNode(enableSaturation: self.enableSaturation)
                } else {
                    self.backgroundNode = WallpaperLightButtonBackgroundNode()
                }
                self.insertSubnode(self.backgroundNode, at: 0)
            }
        }
    }
    
    private var backgroundNode: ASDisplayNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private var animationNode: AnimationNode?
    
    func setIcon(_ image: UIImage?) {
        self.iconNode.image = generateTintedImage(image: image, color: .white)
    }
    
    init(content: Content, dark: Bool) {
        self.content = content
        self.dark = dark
        
        if dark {
            self.backgroundNode = WallpaperOptionBackgroundNode(enableSaturation: self.enableSaturation)
        } else {
            self.backgroundNode = WallpaperLightButtonBackgroundNode()
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.contentMode = .center
        
        var title: String
        switch content {
        case let .text(text):
            title = text
        case let .icon(icon, _):
            title = ""
            self.iconNode.image = generateTintedImage(image: icon, color: .white)
        case let .dayNight(isNight):
            title = ""
            let animationNode = AnimationNode(animation: isNight ? "anim_sun_reverse" : "anim_sun", colors: [:], scale: 1.0)
            animationNode.speed = 1.66
            animationNode.isUserInteractionEnabled = false
            self.animationNode = animationNode
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: .white)
        
        super.init()
        
        self.isExclusiveTouch = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
        
        if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        }
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.4
                    
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                    
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                    
//                    if let animationNode = strongSelf.animationNode {
//                        animationNode.layer.removeAnimation(forKey: "opacity")
//                        animationNode.alpha = 0.4
//                    }
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
//                    if let animationNode = strongSelf.animationNode {
//                        animationNode.alpha = 1.0
//                        animationNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
//                    }
                }
            }
        }
    }
    
    func setIsNight(_ isNight: Bool) {
        self.animationNode?.setAnimation(name: !isNight ? "anim_sun_reverse" : "anim_sun", colors: [:])
        self.animationNode?.speed = 1.66
        self.animationNode?.playOnce()
        
        self.isUserInteractionEnabled = false
        Queue.mainQueue().after(0.4) {
            self.isUserInteractionEnabled = true
        }
    }
    
    var buttonColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.3) {
        didSet {
        }
    }
    
    private var textSize: CGSize?
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        switch self.content {
        case .text:
            let size = self.textNode.updateLayout(constrainedSize)
            self.textSize = size
            return CGSize(width: ceil(size.width) + 16.0, height: 28.0)
        case let .icon(_, size):
            return size
        case .dayNight:
            return CGSize(width: 28.0, height: 28.0)
        }
    }
    
    override func layout() {
        super.layout()

        let size = self.bounds.size
        self.backgroundNode.frame = self.bounds
        if let backgroundNode = self.backgroundNode as? WallpaperOptionBackgroundNode {
            backgroundNode.updateLayout(size: self.backgroundNode.bounds.size)
        } else if let backgroundNode = self.backgroundNode as? WallpaperLightButtonBackgroundNode {
            backgroundNode.updateLayout(size: self.backgroundNode.bounds.size)
        }
        self.backgroundNode.cornerRadius = size.height / 2.0
        
        self.iconNode.frame = self.bounds
        
        if let textSize = self.textSize {
            self.textNode.frame = CGRect(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0), width: textSize.width, height: textSize.height)
        }
        
        if let animationNode = self.animationNode {
            animationNode.bounds = CGRect(origin: .zero, size: CGSize(width: 24.0, height: 24.0))
            animationNode.position = CGPoint(x: 14.0, y: 14.0)
        }
    }
}


final class WallpaperOptionButtonNode: HighlightTrackingButtonNode {
    let backgroundNode: WallpaperOptionBackgroundNode
    
    private let checkNode: CheckNode
    private let colorNode: ASImageNode
    
    private let textNode: ImmediateTextNode
    
    private var textSize: CGSize?
    
    private var _value: WallpaperOptionButtonValue
    override var isSelected: Bool {
        get {
            switch self._value {
            case let .check(selected), let .color(selected, _), let .colors(selected, _):
                return selected
            }
        }
        set {
            switch self._value {
            case .check:
                self._value = .check(newValue)
            case let .color(_, color):
                self._value = .color(newValue, color)
            case let .colors(_, colors):
                self._value = .colors(newValue, colors)
            }
            self.checkNode.setSelected(newValue, animated: false)
        }
    }
    
    var title: String {
        didSet {
            self.textNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: .white)
        }
    }
    
    init(title: String, value: WallpaperOptionButtonValue) {
        self._value = value
        self.title = title
        
        self.backgroundNode = WallpaperOptionBackgroundNode()
        
        self.checkNode = CheckNode(theme: CheckNodeTheme(backgroundColor: .white, strokeColor: .clear, borderColor: .white, overlayBorder: false, hasInset: false, hasShadow: false, borderWidth: 1.5))
        self.checkNode.isUserInteractionEnabled = false
        
        self.colorNode = ASImageNode()
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: .white)

        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 14.0
        self.isExclusiveTouch = true
        
        switch value {
        case let .check(selected):
            self.checkNode.isHidden = false
            self.colorNode.isHidden = true
            self.checkNode.selected = selected
        case let .color(_, color):
            self.checkNode.isHidden = true
            self.colorNode.isHidden = false
            self.colorNode.image = generateFilledCircleImage(diameter: 18.0, color: color)
        case let .colors(_, colors):
            self.checkNode.isHidden = true
            self.colorNode.isHidden = false
            self.colorNode.image = generateColorsImage(diameter: 18.0, colors: colors)
        }
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.checkNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.colorNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.4
                    
                    strongSelf.colorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.colorNode.alpha = 0.4
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.colorNode.alpha = 1.0
                    strongSelf.colorNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    var buttonColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.3) {
        didSet {
        }
    }
    
    var color: UIColor? {
        get {
            switch self._value {
                case let .color(_, color):
                    return color
                default:
                    return nil
            }
        }
        set {
            if let color = newValue {
                switch self._value {
                    case let .color(selected, _):
                        self._value = .color(selected, color)
                        self.colorNode.image = generateFilledCircleImage(diameter: 18.0, color: color)
                    default:
                        break
                }
            }
        }
    }

    var colors: [UIColor]? {
        get {
            switch self._value {
            case let .colors(_, colors):
                return colors
            default:
                return nil
            }
        }
        set {
            if let colors = newValue {
                switch self._value {
                case let .colors(selected, current):
                    if current.count == colors.count {
                        var updated = false
                        for i in 0 ..< current.count {
                            if !current[i].isEqual(colors[i]) {
                                updated = true
                                break
                            }
                        }
                        if !updated {
                            return
                        }
                    }
                    self._value = .colors(selected, colors)
                    self.colorNode.image = generateColorsImage(diameter: 18.0, colors: colors)
                default:
                    break
                }
            }
        }
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        switch self._value {
        case .check:
            self._value = .check(selected)
        case let .color(_, color):
            self._value = .color(selected, color)
        case let .colors(_, colors):
            self._value = .colors(selected, colors)
        }
        self.checkNode.setSelected(selected, animated: animated)
    }
    
    func setEnabled(_ enabled: Bool) {
        let alpha: CGFloat = enabled ? 1.0 : 0.4
        self.checkNode.alpha = alpha
        self.colorNode.alpha = alpha
        self.textNode.alpha = alpha
        self.isUserInteractionEnabled = enabled
    }
    
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        self.textSize = size
        return CGSize(width: ceil(size.width) + 48.0, height: 30.0)
    }
    
    override func layout() {
        super.layout()

        self.backgroundNode.frame = self.bounds
        self.backgroundNode.updateLayout(size: self.backgroundNode.bounds.size)
        
        guard let _ = self.textSize else {
            return
        }
        
        let padding: CGFloat = 6.0
        let spacing: CGFloat = 9.0
        let checkSize = CGSize(width: 18.0, height: 18.0)
        let checkFrame = CGRect(origin: CGPoint(x: padding, y: padding), size: checkSize)
        self.checkNode.frame = checkFrame
        self.colorNode.frame = checkFrame
        
        if let textSize = self.textSize {
            self.textNode.frame = CGRect(x: max(padding + checkSize.width + spacing, padding + checkSize.width + floor((self.bounds.width - padding - checkSize.width - textSize.width) / 2.0) - 2.0), y: floorToScreenPixels((self.bounds.height - textSize.height) / 2.0), width: textSize.width, height: textSize.height)
        }
    }
}

final class WallpaperSliderNode: ASDisplayNode {
    let minValue: CGFloat
    let maxValue: CGFloat
    var value: CGFloat = 1.0 {
        didSet {
            if let size = self.validLayout {
                self.updateLayout(size: size)
            }
        }
    }
    
    private let backgroundNode: NavigationBackgroundNode
    
    private let foregroundNode: ASDisplayNode
    private let foregroundLightNode: ASDisplayNode
    private let leftIconNode: ASImageNode
    private let rightIconNode: ASImageNode
    
    private let valueChanged: (CGFloat, Bool) -> Void
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: CGSize?

    init(minValue: CGFloat, maxValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.valueChanged = valueChanged
        
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x333333, alpha: 0.35), enableBlur: true, enableSaturation: false)
       
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.clipsToBounds = true
        self.foregroundNode.cornerRadius = 3.0
        self.foregroundNode.isAccessibilityElement = false
        self.foregroundNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.75)
        self.foregroundNode.layer.compositingFilter = "overlayBlendMode"
        self.foregroundNode.isUserInteractionEnabled = false
     
        self.foregroundLightNode = ASDisplayNode()
        self.foregroundLightNode.clipsToBounds = true
        self.foregroundLightNode.cornerRadius = 3.0
        self.foregroundLightNode.backgroundColor = UIColor(rgb: 0xf2f2f2, alpha: 0.2)
        
        self.leftIconNode = ASImageNode()
        self.leftIconNode.displaysAsynchronously = false
        self.leftIconNode.image = UIImage(bundleImageName: "Settings/WallpaperBrightnessMin")
        self.leftIconNode.contentMode = .center
        
        self.rightIconNode = ASImageNode()
        self.rightIconNode.displaysAsynchronously = false
        self.rightIconNode.image = UIImage(bundleImageName: "Settings/WallpaperBrightnessMax")
        self.rightIconNode.contentMode = .center
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 15.0
        self.isUserInteractionEnabled = true
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.foregroundNode)
        self.addSubnode(self.foregroundLightNode)
        
        self.addSubnode(self.leftIconNode)
        self.addSubnode(self.rightIconNode)
    }
    
    override func didLoad() {
        super.didLoad()
                
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.view.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    var ignoreUpdates = false
    func animateValue(from: CGFloat, to: CGFloat, transition: ContainedViewLayoutTransition = .immediate) {
        guard let size = self.validLayout else {
            return
        }
        self.internalUpdateLayout(size: size, value: from)
        self.internalUpdateLayout(size: size, value: to, transition: transition)
    }
    
    func internalUpdateLayout(size: CGSize, value: CGFloat, transition: ContainedViewLayoutTransition = .immediate) {
        self.validLayout = size
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: .zero, size: size))
        self.backgroundNode.update(size: size, transition: transition)
        
        if let icon = self.leftIconNode.image {
            transition.updateFrame(node: self.leftIconNode, frame: CGRect(origin: CGPoint(x: 7.0, y: floorToScreenPixels((size.height - icon.size.height) / 2.0)), size: icon.size))
        }
        
        if let icon = self.rightIconNode.image {
            transition.updateFrame(node: self.rightIconNode, frame: CGRect(origin: CGPoint(x: size.width - icon.size.width - 6.0, y: floorToScreenPixels((size.height - icon.size.height) / 2.0)), size: icon.size))
        }
        
        let range = self.maxValue - self.minValue
        let value = (value - self.minValue) / range
        let foregroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: value * size.width, height: size.height))
        transition.updateFrame(node: self.foregroundNode, frame: foregroundFrame)
        transition.updateFrame(node: self.foregroundLightNode, frame: foregroundFrame)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        guard !self.ignoreUpdates else {
            return
        }
        self.internalUpdateLayout(size: size, value: self.value, transition: transition)
    }
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let range = self.maxValue - self.minValue
        switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                let previousValue = self.value
                
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                gestureRecognizer.setTranslation(CGPoint(), in: gestureRecognizer.view)
                
                if self.value == 0.0 && previousValue != 0.0 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 1.0 && previousValue != 1.0 {
                    self.hapticFeedback.impact(.soft)
                }
                if abs(previousValue - self.value) >= 0.001 {
                    self.valueChanged(self.value, false)
                }
            case .ended:
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                self.valueChanged(self.value, true)
            default:
                break
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let range = self.maxValue - self.minValue
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        self.value = max(self.minValue, min(self.maxValue, self.minValue + location.x / self.bounds.width * range))
        self.valueChanged(self.value, true)
    }
}
