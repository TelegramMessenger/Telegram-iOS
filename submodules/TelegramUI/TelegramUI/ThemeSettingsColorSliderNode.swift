import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences

private let shadowImage: UIImage = {
    return generateImage(CGSize(width: 54.0, height: 54.0), opaque: false, scale: nil, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setShadow(offset: CGSize(width: 0.0, height: 1.5), blur: 3.5, color: UIColor(rgb: 0x000000, alpha: 0.65).cgColor)
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: 4.5 + UIScreenPixel, dy: 4.5 + UIScreenPixel))
    })!
}()

private final class ColorsParameter: NSObject {
    let leftColor: UIColor
    let baseColor: UIColor
    let rightColor: UIColor
    let value: CGFloat
    
    init(leftColor: UIColor, baseColor: UIColor, rightColor: UIColor, value: CGFloat) {
        self.leftColor = leftColor
        self.baseColor = baseColor
        self.rightColor = rightColor
        self.value = value
        super.init()
    }
}

private final class ThemeSettingsColorKnobNode: ASDisplayNode {
    var values: (UIColor, UIColor, UIColor, CGFloat) = (.clear, .clear, .clear, 0.5) {
        didSet {
            if self.values != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = false
        self.isUserInteractionEnabled = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ColorsParameter(leftColor: self.values.0, baseColor: self.values.1, rightColor: self.values.2, value: self.values.3)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? ColorsParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        context.draw(shadowImage.cgImage!, in: bounds)
        
        context.setBlendMode(.normal)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0, dy: 3.0))
        
        let color: UIColor
        if parameters.value < 0.5 {
            color = parameters.baseColor.interpolateTo(parameters.leftColor, fraction: 0.5 - parameters.value)!
        } else if parameters.value > 0.5 {
            color = parameters.baseColor.interpolateTo(parameters.rightColor, fraction: parameters.value - 0.5)!
        } else {
            color = parameters.baseColor
        }
        
        context.setFillColor(color.cgColor)
        
        let borderWidth: CGFloat = bounds.width > 30.0 ? 5.0 : 5.0
        context.fillEllipse(in: bounds.insetBy(dx: borderWidth - UIScreenPixel, dy: borderWidth - UIScreenPixel))
    }
}

private final class ThemeSettingsColorBrightnessNode: ASDisplayNode {
    var values: (UIColor, UIColor, UIColor, CGFloat) = (.clear, .clear, .clear, 0.5) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ColorsParameter(leftColor: self.values.0, baseColor: self.values.1, rightColor: self.values.2, value: self.values.3)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? ColorsParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        context.clear(bounds)
        
        let innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2.0)
        context.addPath(innerPath.cgPath)
        context.clip()
        
        let colors = [parameters.leftColor.cgColor, parameters.baseColor.cgColor, parameters.rightColor.cgColor]
        var locations: [CGFloat] = [0.0, 0.5, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
    }
}

final class ThemeSettingsColorSliderNode: ASDisplayNode {
    private let brightnessNode: ThemeSettingsColorBrightnessNode
    private let brightnessKnobNode: ThemeSettingsColorKnobNode
    
    private var validLayout: CGSize?
    private var panning = false
    
    var valueChanged: ((CGFloat) -> Void)?
    
    var baseColor: PresentationThemeBaseColor = .white {
        didSet {
            let colors = self.baseColor.edgeColors
            self.brightnessNode.values = (colors.0, self.baseColor.color, colors.1, 0.5)
            self.update()
        }
    }
    
    var _value: CGFloat = 0.5
    var lastReportedValue: CGFloat?
    
    var value: CGFloat {
        get {
            return _value
        }
        set {
            self._value = newValue
            self.update()
            if let validLayout = self.validLayout {
                self.updateKnobLayout(size: validLayout, transition: .immediate)
            }
        }
    }
    
    override init() {
        self.brightnessNode = ThemeSettingsColorBrightnessNode()
        self.brightnessNode.hitTestSlop = UIEdgeInsetsMake(-16.0, -16.0, -16.0, -16.0)
        self.brightnessKnobNode = ThemeSettingsColorKnobNode()
       
        super.init()
        
        self.backgroundColor = .clear
        
        self.addSubnode(self.brightnessNode)
        self.addSubnode(self.brightnessKnobNode)
        
        self.update()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.brightnessNode.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.brightnessPan)))
    }
    
    private func update() {
        let colors = self.baseColor.edgeColors
        self.brightnessKnobNode.values = (colors.0, self.baseColor.color, colors.1, self.value)
    }
    
    func updateKnobLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let inset: CGFloat = 30.0
        let brightnessKnobSize = CGSize(width: 54.0, height: 54.0)
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (self.value), y: floor((size.height - brightnessKnobSize.height) / 2.0), width: brightnessKnobSize.width, height: brightnessKnobSize.height)
        transition.updateFrame(node: self.brightnessKnobNode, frame: brightnessKnobFrame)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let inset: CGFloat = 16.0
        transition.updateFrame(node: self.brightnessNode, frame: CGRect(x: inset, y: floor((size.height - 30.0) / 2.0), width: size.width - inset * 2.0, height: 30.0))
        
        if !self.panning {
            self.updateKnobLayout(size: size, transition: .immediate)
        }
    }
    
    @objc private func brightnessPan(_ recognizer: UIPanGestureRecognizer) {
        guard let size = self.validLayout else {
            return
        }
        
        let previousValue = self.value
        let transition = recognizer.translation(in: recognizer.view)
        let brightnessWidth: CGFloat = size.width - 16.0 * 2.0
        let newValue = max(0.0, min(1.0, self.value + transition.x / brightnessWidth))
        self._value = newValue
        
        var ended = false
        switch recognizer.state {
            case .changed:
                self.panning = true
                self.updateKnobLayout(size: size, transition: .immediate)
                recognizer.setTranslation(CGPoint(), in: recognizer.view)
            case .ended:
                self.updateKnobLayout(size: size, transition: .immediate)
                self.panning = false
                ended = true
            default:
                break
        }
        
        var update = true
        if let lastReportedValue = self.lastReportedValue, abs(self.value - lastReportedValue) < 0.05 {
            update = false
        }
        
        if update || ended {
            self.update()
            self.valueChanged?(self.value)
            self.lastReportedValue = self.value
            print("upda")
        }
    }
}
