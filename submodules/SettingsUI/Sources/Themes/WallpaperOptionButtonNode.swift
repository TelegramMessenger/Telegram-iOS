import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import CheckNode

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

final class WallpaperNavigationButtonNode: HighlightTrackingButtonNode {
    enum Content {
        case icon(image: UIImage?, size: CGSize)
        case text(String)
    }
    
    private let content: Content
    
    private let backgroundNode: NavigationBackgroundNode
    private let vibrancyView: UIVisualEffectView
    
    private let iconNode: ASImageNode
    private let darkIconNode: ASImageNode
    
    private let textNode: ImmediateTextNode
    private let darkTextNode: ImmediateTextNode
    
    func setIcon(_ image: UIImage?) {
        self.iconNode.image = generateTintedImage(image: image, color: .white)
        self.darkIconNode.image = generateTintedImage(image: image, color: UIColor(rgb: 0x000000, alpha: 0.25))
    }
    
    init(content: Content) {
        self.content = content
        
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0xf2f2f2, alpha: 0.75))
        self.backgroundNode.cornerRadius = 14.0
        
        let blurEffect: UIBlurEffect
        if #available(iOS 13.0, *) {
            blurEffect = UIBlurEffect(style: .extraLight)
        } else {
            blurEffect = UIBlurEffect(style: .light)
        }
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.contentMode = .center
        
        self.darkIconNode = ASImageNode()
        self.darkIconNode.displaysAsynchronously = false
        self.darkIconNode.contentMode = .center
        
        var title: String
        switch content {
        case let .text(text):
            title = text
            self.backgroundNode.cornerRadius = 14.0
        case let .icon(icon, size):
            title = ""
            self.backgroundNode.cornerRadius = size.height / 2.0
            
            self.iconNode.image = generateTintedImage(image: icon, color: .white)
            self.darkIconNode.image = generateTintedImage(image: icon, color: UIColor(rgb: 0x000000, alpha: 0.25))
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: .white)
        
        self.darkTextNode = ImmediateTextNode()
        self.darkTextNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: UIColor(rgb: 0x000000, alpha: 0.25))
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.vibrancyView.contentView.addSubnode(self.iconNode)
        self.vibrancyView.contentView.addSubnode(self.textNode)
        self.backgroundNode.view.addSubview(self.vibrancyView)
        self.backgroundNode.addSubnode(self.darkIconNode)
        self.backgroundNode.addSubnode(self.darkTextNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.4
                    
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                    
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    var buttonColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.3) {
        didSet {
            if self.buttonColor == UIColor(rgb: 0x000000, alpha: 0.3) {
                self.backgroundNode.updateColor(color: UIColor(rgb: 0xf2f2f2, alpha: 0.75), transition: .immediate)
            } else {
                self.backgroundNode.updateColor(color: self.buttonColor, transition: .immediate)
            }
        }
    }
    
    private var textSize: CGSize?
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        switch self.content {
        case .text:
            let size = self.textNode.updateLayout(constrainedSize)
            let _ = self.darkTextNode.updateLayout(constrainedSize)
            self.textSize = size
            return CGSize(width: ceil(size.width) + 16.0, height: 28.0)
        case let .icon(_, size):
            return size
        }
    }
    
    override func layout() {
        super.layout()

        let size = self.bounds.size
        self.backgroundNode.frame = self.bounds
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: 14.0, transition: .immediate)
        self.vibrancyView.frame = self.bounds
        
        self.iconNode.frame = self.bounds
        self.darkIconNode.frame = self.bounds
        
        if let textSize = self.textSize {
            self.textNode.frame = CGRect(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0), width: textSize.width, height: textSize.height)
            self.darkTextNode.frame = self.textNode.frame
        }
    }
}


final class WallpaperOptionButtonNode: HighlightTrackingButtonNode {
    private let backgroundNode: NavigationBackgroundNode
    private let vibrancyView: UIVisualEffectView
    
    private let checkNode: CheckNode
    private let darkCheckNode: CheckNode
    
    private let colorNode: ASImageNode
    
    private let textNode: ImmediateTextNode
    private let darkTextNode: ImmediateTextNode
    
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
            self.darkCheckNode.setSelected(newValue, animated: false)
        }
    }
    
    var title: String {
        didSet {
            self.textNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: .white)
            self.darkTextNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: UIColor(rgb: 0x000000, alpha: 0.25))
        }
    }
    
    init(title: String, value: WallpaperOptionButtonValue) {
        self._value = value
        self.title = title
        
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0xffffff, alpha: 0.4))
        self.backgroundNode.cornerRadius = 14.0
        
        let blurEffect: UIBlurEffect
        if #available(iOS 13.0, *) {
            blurEffect = UIBlurEffect(style: .extraLight)
        } else {
            blurEffect = UIBlurEffect(style: .light)
        }
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        
        let darkColor = UIColor(rgb: 0x000000, alpha: 0.25)
        
        self.checkNode = CheckNode(theme: CheckNodeTheme(backgroundColor: .white, strokeColor: .clear, borderColor: .white, overlayBorder: false, hasInset: false, hasShadow: false, borderWidth: 1.5))
        self.checkNode.isUserInteractionEnabled = false
        
        self.darkCheckNode = CheckNode(theme: CheckNodeTheme(backgroundColor: darkColor, strokeColor: .clear, borderColor: darkColor, overlayBorder: false, hasInset: false, hasShadow: false, borderWidth: 1.5))
        self.darkCheckNode.isUserInteractionEnabled = false
        
        self.colorNode = ASImageNode()
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: .white)
        
        self.darkTextNode = ImmediateTextNode()
        self.darkTextNode.displaysAsynchronously = false
        self.darkTextNode.attributedText = NSAttributedString(string: title, font: Font.medium(13), textColor: UIColor(rgb: 0x000000, alpha: 0.25))
        
        super.init()
        
        switch value {
        case let .check(selected):
            self.checkNode.isHidden = false
            self.darkCheckNode.isHidden = false
            self.colorNode.isHidden = true
            self.checkNode.selected = selected
            self.darkCheckNode.selected = selected
        case let .color(_, color):
            self.checkNode.isHidden = true
            self.darkCheckNode.isHidden = true
            self.colorNode.isHidden = false
            self.colorNode.image = generateFilledCircleImage(diameter: 18.0, color: color)
        case let .colors(_, colors):
            self.checkNode.isHidden = true
            self.darkCheckNode.isHidden = true
            self.colorNode.isHidden = false
            self.colorNode.image = generateColorsImage(diameter: 18.0, colors: colors)
        }
        
        self.addSubnode(self.backgroundNode)
        self.vibrancyView.contentView.addSubnode(self.checkNode)
        self.vibrancyView.contentView.addSubnode(self.textNode)
        self.backgroundNode.view.addSubview(self.vibrancyView)
        self.addSubnode(self.darkCheckNode)
        self.addSubnode(self.darkTextNode)
        self.addSubnode(self.colorNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.4
                    
                    strongSelf.checkNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.checkNode.alpha = 0.4
                    
                    strongSelf.colorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.colorNode.alpha = 0.4
                    
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.checkNode.alpha = 1.0
                    strongSelf.checkNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.colorNode.alpha = 1.0
                    strongSelf.colorNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    var buttonColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.3) {
        didSet {
            if self.buttonColor == UIColor(rgb: 0x000000, alpha: 0.3) {
                self.backgroundNode.updateColor(color: UIColor(rgb: 0xf2f2f2, alpha: 0.75), transition: .immediate)
            } else {
                self.backgroundNode.updateColor(color: self.buttonColor, transition: .immediate)
            }
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
        self.darkCheckNode.setSelected(selected, animated: animated)
    }
    
    func setEnabled(_ enabled: Bool) {
        let alpha: CGFloat = enabled ? 1.0 : 0.4
        self.backgroundNode.alpha = alpha
        self.checkNode.alpha = alpha
        self.colorNode.alpha = alpha
        self.textNode.alpha = alpha
        self.isUserInteractionEnabled = enabled
    }
    
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        let _ = self.darkTextNode.updateLayout(constrainedSize)
        self.textSize = size
        return CGSize(width: ceil(size.width) + 48.0, height: 30.0)
    }
    
    override func layout() {
        super.layout()

        self.backgroundNode.frame = self.bounds
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: 15.0, transition: .immediate)
        self.vibrancyView.frame = self.bounds
        
        guard let _ = self.textSize else {
            return
        }
        
        let padding: CGFloat = 6.0
        let spacing: CGFloat = 9.0
        let checkSize = CGSize(width: 18.0, height: 18.0)
        let checkFrame = CGRect(origin: CGPoint(x: padding, y: padding), size: checkSize)
        self.checkNode.frame = checkFrame
        self.darkCheckNode.frame = checkFrame
        self.colorNode.frame = checkFrame
        
        if let textSize = self.textSize {
            self.textNode.frame = CGRect(x: max(padding + checkSize.width + spacing, padding + checkSize.width + floor((self.bounds.width - padding - checkSize.width - textSize.width) / 2.0) - 2.0), y: floorToScreenPixels((self.bounds.height - textSize.height) / 2.0), width: textSize.width, height: textSize.height)
            self.darkTextNode.frame = self.textNode.frame
        }
    }
}
