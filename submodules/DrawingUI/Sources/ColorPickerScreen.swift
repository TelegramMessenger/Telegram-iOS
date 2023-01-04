import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import LegacyComponents
import TelegramCore
import Postbox
import AccountContext
import TelegramPresentationData
import SheetComponent
import ViewControllerComponent
import SegmentedControlNode
import MultilineTextComponent
import HexColor

private let palleteColors: [UInt32] = [
    0xffffff, 0xebebeb, 0xd6d6d6, 0xc2c2c2, 0xadadad, 0x999999, 0x858585, 0x707070, 0x5c5c5c, 0x474747, 0x333333, 0x000000,
    0x00374a, 0x011d57, 0x11053b, 0x2e063d, 0x3c071b, 0x5c0701, 0x5a1c00, 0x583300, 0x563d00, 0x666100, 0x4f5504, 0x263e0f,
    0x004d65, 0x012f7b, 0x1a0a52, 0x450d59, 0x551029, 0x831100, 0x7b2900, 0x7a4a00, 0x785800, 0x8d8602, 0x6f760a, 0x38571a,
    0x016e8f, 0x0042a9, 0x2c0977, 0x61187c, 0x791a3d, 0xb51a00, 0xad3e00, 0xa96800, 0xa67b01, 0xc4bc00, 0x9ba50e, 0x4e7a27,
    0x008cb4, 0x0056d6, 0x371a94, 0x7a219e, 0x99244f, 0xe22400, 0xda5100, 0xd38301, 0xd19d01, 0xf5ec00, 0xc3d117, 0x669d34,
    0x00a1d8, 0x0061fe, 0x4d22b2, 0x982abc, 0xb92d5d, 0xff4015, 0xff6a00, 0xffab01, 0xfdc700, 0xfefb41, 0xd9ec37, 0x76bb40,
    0x01c7fc, 0x3a87fe, 0x5e30eb, 0xbe38f3, 0xe63b7a, 0xff6250, 0xff8648, 0xfeb43f, 0xfecb3e, 0xfff76b, 0xe4ef65, 0x96d35f,
    0x52d6fc, 0x74a7ff, 0x864ffe, 0xd357fe, 0xee719e, 0xff8c82, 0xffa57d, 0xffc777, 0xffd977, 0xfff994, 0xeaf28f, 0xb1dd8b,
    0x93e3fd, 0xa7c6ff, 0xb18cfe, 0xe292fe, 0xf4a4c0, 0xffb5af, 0xffc5ab, 0xffd9a8, 0xfee4a8, 0xfffbb9, 0xf2f7b7, 0xcde8b5,
    0xcbf0ff, 0xd3e2ff, 0xd9c9fe, 0xefcaff, 0xf9d3e0, 0xffdbd8, 0xffe2d6, 0xffecd4, 0xfff2d5, 0xfefcdd, 0xf7fadb, 0xdfeed4
]

private class GradientLayer: CAGradientLayer {
    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

private struct ColorSelectionImage: Equatable {
    var _image: UIImage?
    let size: CGSize
    let topLeftRadius: CGFloat
    let topRightRadius: CGFloat
    let bottomLeftRadius: CGFloat
    let bottomRightRadius: CGFloat
    let isLight: Bool
    
    init(size: CGSize, topLeftRadius: CGFloat, topRightRadius: CGFloat, bottomLeftRadius: CGFloat, bottomRightRadius: CGFloat, isLight: Bool) {
        self.size = size
        self.topLeftRadius = topLeftRadius
        self.topRightRadius = topRightRadius
        self.bottomLeftRadius = bottomLeftRadius
        self.bottomRightRadius = bottomRightRadius
        self.isLight = isLight
    }
    
    public static func ==(lhs: ColorSelectionImage, rhs: ColorSelectionImage) -> Bool {
        if lhs.size != rhs.size {
            return false
        }
        if lhs.topLeftRadius != rhs.topLeftRadius {
            return false
        }
        if lhs.topRightRadius != rhs.topRightRadius {
            return false
        }
        if lhs.bottomLeftRadius != rhs.bottomLeftRadius {
            return false
        }
        if lhs.bottomRightRadius != rhs.bottomRightRadius {
            return false
        }
        if lhs.isLight != rhs.isLight {
            return false
        }
        return true
    }
    
    mutating func getImage() -> UIImage {
        if self._image == nil {
            self._image = generateColorSelectionImage(size: self.size, topLeftRadius: self.topLeftRadius, topRightRadius: self.topRightRadius, bottomLeftRadius: self.bottomLeftRadius, bottomRightRadius: self.bottomRightRadius, isLight: self.isLight)
        }
        return self._image!
    }
}

private func generateColorSelectionImage(size: CGSize, topLeftRadius: CGFloat, topRightRadius: CGFloat, bottomLeftRadius: CGFloat, bottomRightRadius: CGFloat, isLight: Bool) -> UIImage? {
    let margin: CGFloat = 10.0
    let realSize = size
    
    let image = generateImage(CGSize(width: size.width + margin * 2.0, height: size.height + margin * 2.0), opaque: false, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        let path = UIBezierPath(roundRect: CGRect(origin: CGPoint(x: margin, y: margin), size: realSize), topLeftRadius: topLeftRadius, topRightRadius: topRightRadius, bottomLeftRadius: bottomLeftRadius, bottomRightRadius: bottomRightRadius)
        context.addPath(path.cgPath)
        
        context.setShadow(offset: CGSize(), blur: 9.0, color: UIColor(rgb: 0x000000, alpha: 0.15).cgColor)
        context.setLineWidth(3.0 - UIScreenPixel)
        context.setStrokeColor(UIColor(rgb: isLight ? 0xffffff : 0x1a1a1c).cgColor)
        context.strokePath()
    })
    return image
}

private func generateColorGridImage(size: CGSize) -> UIImage? {
    return generateImage(size, opaque: true, rotatedContext: { size, context in
        let squareSize = floorToScreenPixels(size.width / 12.0)
        var index = 0
        for row in 0 ..< 10 {
            for col in 0 ..< 12 {
                let color = palleteColors[index]
                var correctedSize = squareSize
                if col == 11 {
                    correctedSize = size.width - squareSize * 11.0
                }
                let rect = CGRect(origin: CGPoint(x: CGFloat(col) * squareSize, y: CGFloat(row) * squareSize), size: CGSize(width: correctedSize, height: squareSize))
                
                context.setFillColor(UIColor(rgb: color).cgColor)
                context.fill(rect)
                
                index += 1
            }
        }
    })
}

private func generateCheckeredImage(size: CGSize, whiteColor: UIColor, blackColor: UIColor, length: CGFloat) -> UIImage? {
    return generateImage(size, opaque: false, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        let w = Int(ceil(size.width / length))
        let h = Int(ceil(size.height / length))
        for i in 0 ..< w {
            for j in 0 ..< h {
                if (i % 2) != (j % 2) {
                    context.setFillColor(whiteColor.cgColor)
                } else {
                    context.setFillColor(blackColor.cgColor)
                }
                context.fill(CGRect(origin: CGPoint(x: CGFloat(i) * length, y: CGFloat(j) * length), size: CGSize(width: length, height: length)))
            }
        }
    })
}

private func generateKnobImage() -> UIImage? {
    let side: CGFloat = 32.0
    let margin: CGFloat = 10.0
    
    let image = generateImage(CGSize(width: side + margin * 2.0, height: side + margin * 2.0), opaque: false, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
                
        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 9.0, color: UIColor(rgb: 0x000000, alpha: 0.3).cgColor)
        context.setFillColor(UIColor(rgb: 0x1a1a1c).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: margin, y: margin), size: CGSize(width: side, height: side)))
    })
    return image
}

private class ColorSliderComponent: Component {
    let leftColor: DrawingColor
    let rightColor: DrawingColor
    let currentColor: DrawingColor
    let value: CGFloat
    let updated: (CGFloat) -> Void
    
    public init(
        leftColor: DrawingColor,
        rightColor: DrawingColor,
        currentColor: DrawingColor,
        value: CGFloat,
        updated: @escaping (CGFloat) -> Void
    ) {
        self.leftColor = leftColor
        self.rightColor = rightColor
        self.currentColor = currentColor
        self.value = value
        self.updated = updated
    }
    
    public static func ==(lhs: ColorSliderComponent, rhs: ColorSliderComponent) -> Bool {
        if lhs.leftColor != rhs.leftColor {
            return false
        }
        if lhs.rightColor != rhs.rightColor {
            return false
        }
        if lhs.currentColor != rhs.currentColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private var validSize: CGSize?
        
        private let wrapper = UIView(frame: CGRect())
        private let transparencyLayer = SimpleLayer()
        private let gradientLayer = GradientLayer()
        private let knob = SimpleLayer()
        private let circle = SimpleShapeLayer()
    
        fileprivate var updated: (CGFloat) -> Void = { _ in }
                    
        @objc func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            let side: CGFloat = 36.0
            let location = gestureRecognizer.location(in: self).offsetBy(dx: -side * 0.5, dy: 0.0)
            guard self.frame.width > 0.0, case .began = gestureRecognizer.state else {
                return
            }
            let value = max(0.0, min(1.0, location.x / (self.frame.width - side)))
            self.updated(value)
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            if gestureRecognizer.state == .changed {
                let side: CGFloat = 36.0
                let location = gestureRecognizer.location(in: self).offsetBy(dx: -side * 0.5, dy: 0.0)
                guard self.frame.width > 0.0 else {
                    return
                }
                let value = max(0.0, min(1.0, location.x / (self.frame.width - side)))
                self.updated(value)
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func updateLayout(size: CGSize, leftColor: DrawingColor, rightColor: DrawingColor, currentColor: DrawingColor, value: CGFloat) -> CGSize {
            let previousSize = self.validSize
            
            let sliderSize = CGSize(width: size.width, height: 36.0)
            
            self.validSize = sliderSize
            
            self.gradientLayer.type = .axial
            self.gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            self.gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
            self.gradientLayer.colors = [leftColor.toUIColor().cgColor, rightColor.toUIColor().cgColor]
            
            if leftColor.alpha < 1.0 || rightColor.alpha < 1.0 {
                self.transparencyLayer.isHidden = false
            } else {
                self.transparencyLayer.isHidden = true
            }
            
            if previousSize != sliderSize {
                self.wrapper.frame = CGRect(origin: .zero, size: sliderSize)
                if self.wrapper.superview == nil {
                    self.addSubview(self.wrapper)
                }
                
                self.transparencyLayer.frame = CGRect(origin: .zero, size: sliderSize)
                if self.transparencyLayer.superlayer == nil {
                    self.wrapper.layer.addSublayer(self.transparencyLayer)
                }
                
                self.gradientLayer.frame = CGRect(origin: .zero, size: sliderSize)
                if self.gradientLayer.superlayer == nil {
                    self.wrapper.layer.addSublayer(self.gradientLayer)
                }
                
                if self.knob.superlayer == nil {
                    self.layer.addSublayer(self.knob)
                }
                
                if self.circle.superlayer == nil {
                    self.circle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 26.0, height: 26.0))).cgPath
                    self.layer.addSublayer(self.circle)
                }
                                
                if previousSize == nil {
                    self.isUserInteractionEnabled = true
                    self.wrapper.clipsToBounds = true
                    self.wrapper.layer.cornerRadius = 18.0
                    
                    let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
                    pressGestureRecognizer.minimumPressDuration = 0.01
                    pressGestureRecognizer.delegate = self
                    self.addGestureRecognizer(pressGestureRecognizer)
                    self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:))))
                                        
                    if !self.transparencyLayer.isHidden {
                        self.transparencyLayer.contents = generateCheckeredImage(size: sliderSize, whiteColor: UIColor(rgb: 0xffffff, alpha: 1.0), blackColor: .clear, length: 12.0)?.cgImage
                    }
                    
                    self.knob.contents = generateKnobImage()?.cgImage
                }
            }
            
            let margin: CGFloat = 10.0
            let knobSize = CGSize(width: 32.0, height: 32.0)
            let knobFrame = CGRect(origin: CGPoint(x: 2.0 + floorToScreenPixels((sliderSize.width - 4.0 - knobSize.width) * value), y: 2.0), size: knobSize)
            self.knob.frame = knobFrame.insetBy(dx: -margin, dy: -margin)
            
            self.circle.fillColor = currentColor.toUIColor().cgColor
            self.circle.frame = knobFrame.insetBy(dx: 3.0, dy: 3.0)
            
            return sliderSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.updated = self.updated
        return view.updateLayout(size: availableSize, leftColor: self.leftColor, rightColor: self.rightColor, currentColor: self.currentColor, value: self.value)
    }
}

private class ColorFieldComponent: Component {
    enum FieldType {
        case number
        case text
    }
    let backgroundColor: UIColor
    let textColor: UIColor
    let type: FieldType
    let value: String
    let suffix: String?
    let updated: (String) -> Void
    let shouldUpdate: (String) -> Bool
    
    public init(
        backgroundColor: UIColor,
        textColor: UIColor,
        type: FieldType,
        value: String,
        suffix: String? = nil,
        updated: @escaping (String) -> Void,
        shouldUpdate: @escaping (String) -> Bool
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.type = type
        self.value = value
        self.suffix = suffix
        self.updated = updated
        self.shouldUpdate = shouldUpdate
    }
    
    public static func ==(lhs: ColorFieldComponent, rhs: ColorFieldComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.suffix != rhs.suffix {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private var validSize: CGSize?
        
        private let backgroundNode = NavigationBackgroundNode(color: .clear)
        private let textField = UITextField(frame: CGRect())
        private let suffixLabel = UITextField(frame: CGRect())
        
        fileprivate var updated: (String) -> Void = { _ in }
        fileprivate var shouldUpdate: (String) -> Bool = { _ in return true }
                    
        func updateLayout(size: CGSize, component: ColorFieldComponent) -> CGSize {
            let previousSize = self.validSize
            
            self.updated = component.updated
            self.shouldUpdate = component.shouldUpdate
            
            self.validSize = size
            
            self.backgroundNode.frame = CGRect(origin: .zero, size: size)
            self.backgroundNode.update(size: size, cornerRadius: 9.0, transition: .immediate)
            self.backgroundNode.updateColor(color: component.backgroundColor, transition: .immediate)
                        
            if previousSize == nil {
                self.insertSubview(self.backgroundNode.view, at: 0)
                self.addSubview(self.textField)
                
                self.textField.textAlignment = component.suffix != nil ? .right : .center
                self.textField.delegate = self
                self.textField.font = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: .monospacedNumbers)
                self.textField.addTarget(self, action: #selector(self.textDidChange(_:)), for: .editingChanged)
                self.textField.keyboardAppearance = .dark
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .allCharacters
                
                switch component.type {
                    case .number:
                        self.textField.keyboardType = .numberPad
                    case .text:
                        self.textField.keyboardType = .asciiCapable
                }
            }
            
            self.textField.textColor = component.textColor
            
            var textFieldOffset: CGFloat = 0.0
            if let suffix = component.suffix {
                if self.suffixLabel.superview == nil {
                    self.suffixLabel.isUserInteractionEnabled = false
                    self.suffixLabel.text = suffix
                    self.suffixLabel.font = self.textField.font
                    self.suffixLabel.textColor = self.textField.textColor
                    self.addSubview(self.suffixLabel)
                    
                    self.suffixLabel.sizeToFit()
                    self.suffixLabel.frame = CGRect(origin: CGPoint(x: size.width - self.suffixLabel.frame.width - 14.0, y: floorToScreenPixels((size.height - self.suffixLabel.frame.size.height) / 2.0)), size: self.suffixLabel.frame.size)
                }
                textFieldOffset = -33.0
            } else {
                self.suffixLabel.removeFromSuperview()
            }
            
            self.textField.frame = CGRect(origin: CGPoint(x: textFieldOffset, y: 0.0), size: size)
            self.textField.text = component.value
            
            return size
        }
        
        @objc private func textDidChange(_ textField: UITextField) {
            self.updated(textField.text ?? "")
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            var updated = textField.text ?? ""
            updated.replaceSubrange(updated.index(updated.startIndex, offsetBy: range.lowerBound) ..< updated.index(updated.startIndex, offsetBy: range.upperBound), with: string)
            if self.shouldUpdate(updated) {
                return true
            } else {
                return false
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            return false
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.updated = self.updated
        return view.updateLayout(size: availableSize, component: self)
    }
}

private func generatePreviewBackgroundImage(size: CGSize) -> UIImage? {
    return generateImage(size, opaque: true, rotatedContext: { size, context in
        context.move(to: .zero)
        context.addLine(to: CGPoint(x: size.width, y: 0.0))
        context.addLine(to: CGPoint(x: 0.0, y: size.height))
        context.closePath()
        
        context.setFillColor(UIColor.black.cgColor)
        context.fillPath()
        
        context.move(to: CGPoint(x: size.width, y: 0.0))
        context.addLine(to: CGPoint(x: size.width, y: size.height))
        context.addLine(to: CGPoint(x: 0.0, y: size.height))
        context.closePath()
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    })
}

private class ColorPreviewComponent: Component {
    let color: DrawingColor
    
    public init(
        color: DrawingColor
    ) {
        self.color = color
    }
    
    public static func ==(lhs: ColorPreviewComponent, rhs: ColorPreviewComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var validSize: CGSize?
        
        private let wrapper = UIView(frame: CGRect())
        private let background = SimpleLayer()
        private let color = SimpleLayer()

        func updateLayout(size: CGSize, color: DrawingColor) -> CGSize {
            let previousSize = self.validSize
            
            self.validSize = size
         
            if previousSize != size {
                self.wrapper.frame = CGRect(origin: .zero, size: size)
                if self.wrapper.superview == nil {
                    self.addSubview(self.wrapper)
                }
                
                self.background.frame = CGRect(origin: .zero, size: size)
                if self.background.superlayer == nil {
                    self.wrapper.layer.addSublayer(self.background)
                }
                
                self.color.frame = CGRect(origin: .zero, size: size)
                if self.color.superlayer == nil {
                    self.wrapper.layer.addSublayer(self.color)
                }
                
                if previousSize == nil {
                    self.isUserInteractionEnabled = true
                    self.wrapper.clipsToBounds = true
                    self.wrapper.layer.cornerRadius = 12.0
                    if #available(iOS 13.0, *) {
                        self.wrapper.layer.cornerCurve = .continuous
                    }
                }
                
                self.background.contents = generatePreviewBackgroundImage(size: size)?.cgImage
            }
            
            self.color.backgroundColor = color.toUIColor().cgColor
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.updateLayout(size: availableSize, color: self.color)
    }
}

final class ColorGridComponent: Component {
    let color: DrawingColor?
    let selected: (DrawingColor) -> Void
    
    init(
        color: DrawingColor?,
        selected: @escaping (DrawingColor) -> Void
    ) {
        self.color = color
        self.selected = selected
    }
    
    static func ==(lhs: ColorGridComponent, rhs: ColorGridComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private var validSize: CGSize?
        private var selectedColor: DrawingColor?
        private var selectedColorIndex: Int?
        
        private var wrapper = UIView(frame: CGRect())
        private var image = UIImageView(image: nil)
        private var selectionKnob = UIImageView(image: nil)
        private var selectionKnobImage: ColorSelectionImage?
        
        fileprivate var selected: (DrawingColor) -> Void = { _ in }
                        
        func getColor(at point: CGPoint) -> DrawingColor? {
            guard let size = self.validSize,
                  point.x >= 0 && point.x <= size.width,
                  point.y >= 0 && point.y <= size.height
            else {
                return nil
            }
            let row = Int(point.y / size.height * 10.0)
            let col = Int(point.x / size.width * 12.0)
            
            let index = row * 12 + col
            return DrawingColor(rgb: palleteColors[index])
        }
        
        @objc func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard case .began = gestureRecognizer.state else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            if let color = self.getColor(at: location), color != self.selectedColor {
                self.selected(color)
            }
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            if gestureRecognizer.state == .changed {
                let location = gestureRecognizer.location(in: self)
                if let color = self.getColor(at: location), color != self.selectedColor {
                    self.selected(color)
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func updateLayout(size: CGSize, selectedColor: DrawingColor?) -> CGSize {
            let previousSize = self.validSize
            
            let squareSize = floorToScreenPixels(size.width / 12.0)
            let imageSize = CGSize(width: size.width, height: squareSize * 10.0)
            
            self.validSize = imageSize
            
            let previousColor = self.selectedColor
            self.selectedColor = selectedColor
                        
            if previousSize != imageSize {
                if previousSize == nil {
                    self.isUserInteractionEnabled = true
                    self.wrapper.clipsToBounds = true
                    self.wrapper.layer.cornerRadius = 10.0
                    
                    let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
                    pressGestureRecognizer.delegate = self
                    pressGestureRecognizer.minimumPressDuration = 0.01
                    self.addGestureRecognizer(pressGestureRecognizer)
                    self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:))))
                }
                
                self.wrapper.frame = CGRect(origin: .zero, size: imageSize)
                if self.wrapper.superview == nil {
                    self.addSubview(self.wrapper)
                }
                
                self.image.image = generateColorGridImage(size: imageSize)
                self.image.frame = CGRect(origin: .zero, size: imageSize)
                if self.image.superview == nil {
                    self.wrapper.addSubview(self.image)
                }
            }
            
            if previousColor != selectedColor {
                if let selectedColor = selectedColor {
                    let color = selectedColor.toUIColor().rgb
                    if let index = palleteColors.firstIndex(where: { $0 == color }) {
                        self.selectedColorIndex = index
                    } else {
                        self.selectedColorIndex = nil
                    }
                } else {
                    self.selectedColorIndex = nil
                }
            }
            
            if let selectedColorIndex = self.selectedColorIndex {
                if self.selectionKnob.superview == nil {
                    self.addSubview(self.selectionKnob)
                }
                
                let smallCornerRadius: CGFloat = 2.0
                let largeCornerRadius: CGFloat = 10.0
                
                var topLeftRadius = smallCornerRadius
                var topRightRadius = smallCornerRadius
                var bottomLeftRadius = smallCornerRadius
                var bottomRightRadius = smallCornerRadius
                
                if selectedColorIndex == 0 {
                    topLeftRadius = largeCornerRadius
                } else if selectedColorIndex == 11 {
                    topRightRadius = largeCornerRadius
                } else if selectedColorIndex == palleteColors.count - 12 {
                    bottomLeftRadius = largeCornerRadius
                }  else if selectedColorIndex == palleteColors.count - 1 {
                    bottomRightRadius = largeCornerRadius
                }
                
                let isLight = (selectedColor?.toUIColor().lightness ?? 1.0) < 0.5 ? true : false
                
                var selectionKnobImage = ColorSelectionImage(size: CGSize(width: squareSize, height: squareSize), topLeftRadius: topLeftRadius, topRightRadius: topRightRadius, bottomLeftRadius: bottomLeftRadius, bottomRightRadius: bottomRightRadius, isLight: isLight)
                if selectionKnobImage != self.selectionKnobImage {
                    self.selectionKnob.image = selectionKnobImage.getImage()
                    self.selectionKnobImage = selectionKnobImage
                }
                
                let row = Int(floor(CGFloat(selectedColorIndex) / 12.0))
                let col = selectedColorIndex % 12
                
                let margin: CGFloat = 10.0
                var selectionFrame = CGRect(origin: CGPoint(x: CGFloat(col) * squareSize, y: CGFloat(row) * squareSize), size: CGSize(width: squareSize, height: squareSize))
                selectionFrame = selectionFrame.insetBy(dx: -margin, dy: -margin)
                self.selectionKnob.frame = selectionFrame
            } else {
                self.selectionKnob.image = nil
            }
            
            return CGSize(width: size.width, height: squareSize * 10.0)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.selected = self.selected
        return view.updateLayout(size: availableSize, selectedColor: self.color)
    }
}

private func generateSpectrumImage(size: CGSize) -> UIImage? {
    return generateImage(size, contextGenerator: { size, context in
        if let image = UIImage(bundleImageName: "Media Editor/Spectrum") {
            context.draw(image.cgImage!, in: CGRect(origin: .zero, size: size))
        }
        if let image = UIImage(bundleImageName: "Media Editor/Grayscale") {
            context.draw(image.cgImage!, in: CGRect(origin: .zero, size: size))
        }
    })
}

final class ColorSpectrumComponent: Component {
    let color: DrawingColor?
    let selected: (DrawingColor) -> Void
    
    init(
        color: DrawingColor?,
        selected: @escaping (DrawingColor) -> Void
    ) {
        self.color = color
        self.selected = selected
    }
    
    static func ==(lhs: ColorSpectrumComponent, rhs: ColorSpectrumComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private var validSize: CGSize?
        private var selectedColor: DrawingColor?
        
        private var wrapper = UIView(frame: CGRect())
        private var image = UIImageView(image: nil)

        private let knob = SimpleLayer()
        private let circle = SimpleShapeLayer()
        
        fileprivate var selected: (DrawingColor) -> Void = { _ in }
                        
        private var bitmapData: UnsafeMutableRawPointer?
        
        func getColor(at point: CGPoint) -> DrawingColor? {
            guard let size = self.validSize,
                  point.x >= 0 && point.x <= size.width,
                  point.y >= 0 && point.y <= size.height else {
                return nil
            }
            let position = CGPoint(x: point.x / size.width, y: point.y / size.height)
            let scale = self.image.image?.scale ?? 1.0
            let point = CGPoint(x: point.x * scale, y: point.y * scale)
            guard let image = self.image.image?.cgImage else {
                return nil
            }
            
            var redComponent: CGFloat?
            var greenComponent: CGFloat?
            var blueComponent: CGFloat?
            
            let imageWidth = image.width
            let imageHeight = image.height

            let bitmapBytesForRow = Int(imageWidth * 4)
            let bitmapByteCount = bitmapBytesForRow * Int(imageHeight)
            
            if self.bitmapData == nil {
                let imageRect = CGRect(origin: .zero, size: CGSize(width: imageWidth, height: imageHeight))
                                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                
                let bitmapData = malloc(bitmapByteCount)
                let bitmapInformation = CGImageAlphaInfo.premultipliedFirst.rawValue
                
                let colorContext = CGContext(
                    data: bitmapData,
                    width: imageWidth,
                    height: imageHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bitmapBytesForRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInformation
                )
                                
                colorContext?.clear(imageRect)
                colorContext?.draw(image, in: imageRect)
                
                self.bitmapData = bitmapData
            }
            
            self.bitmapData?.withMemoryRebound(to: UInt8.self, capacity: bitmapByteCount) { pointer in
                let offset = 4 * ((Int(imageWidth) * Int(point.y)) + Int(point.x))
                
                redComponent = CGFloat(pointer[offset + 1]) / 255.0
                greenComponent = CGFloat(pointer[offset + 2]) / 255.0
                blueComponent = CGFloat(pointer[offset + 3]) / 255.0
            }
            
            if let redComponent = redComponent, let greenComponent = greenComponent, let blueComponent = blueComponent {
                return DrawingColor(rgb: UIColor(red: redComponent, green: greenComponent, blue: blueComponent, alpha: 1.0).rgb).withUpdatedPosition(position)
            } else {
                return nil
            }
        }
        
        deinit {
            if let bitmapData = self.bitmapData {
                free(bitmapData)
            }
        }
        
        @objc func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard case .began = gestureRecognizer.state else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            if let color = self.getColor(at: location), color != self.selectedColor {
                self.selected(color)
            }
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            if gestureRecognizer.state == .changed {
                let location = gestureRecognizer.location(in: self)
                if let color = self.getColor(at: location), color != self.selectedColor {
                    self.selected(color)
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func updateLayout(size: CGSize, selectedColor: DrawingColor?) -> CGSize {
            let previousSize = self.validSize
            
            let imageSize = size
            self.validSize = imageSize
            
            self.selectedColor = selectedColor
                        
            if previousSize != imageSize {
                if previousSize == nil {
                    self.layer.allowsGroupOpacity = true
                    self.isUserInteractionEnabled = true
                    self.wrapper.clipsToBounds = true
                    self.wrapper.layer.cornerRadius = 10.0
                    
                    let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
                    pressGestureRecognizer.delegate = self
                    pressGestureRecognizer.minimumPressDuration = 0.01
                    self.addGestureRecognizer(pressGestureRecognizer)
                    self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:))))
                }
                
                self.wrapper.frame = CGRect(origin: .zero, size: imageSize)
                if self.wrapper.superview == nil {
                    self.addSubview(self.wrapper)
                }
                
                if let bitmapData = self.bitmapData {
                    free(bitmapData)
                }
                self.image.image = generateSpectrumImage(size: imageSize)
                self.image.frame = CGRect(origin: .zero, size: imageSize)
                if self.image.superview == nil {
                    self.wrapper.addSubview(self.image)
                }
            }
                        
            if let color = selectedColor, let position = color.position {
                if self.knob.superlayer == nil {
                    self.knob.contents = generateKnobImage()?.cgImage
                    self.layer.addSublayer(self.knob)
                }
                if self.circle.superlayer == nil {
                    self.circle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 26.0, height: 26.0))).cgPath
                    self.layer.addSublayer(self.circle)
                }
                
                self.knob.isHidden = false
                self.circle.isHidden = false
                
                let margin: CGFloat = 10.0
                let knobSize = CGSize(width: 32.0, height: 32.0)
                let knobFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width * position.x - knobSize.width / 2.0), y: floorToScreenPixels(size.height * position.y - knobSize.height / 2.0)), size: knobSize)
                self.knob.frame = knobFrame.insetBy(dx: -margin, dy: -margin)
                
                self.circle.fillColor = color.toUIColor().cgColor
                self.circle.frame = knobFrame.insetBy(dx: 3.0, dy: 3.0)
            } else {
                self.knob.isHidden = true
                self.circle.isHidden = true
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.selected = self.selected
        return view.updateLayout(size: availableSize, selectedColor: self.color)
    }
}

final class ColorSpectrumPickerView: UIView, UIGestureRecognizerDelegate {
    private var validSize: CGSize?
    private var selectedColor: DrawingColor?
    
    private var wrapper = UIView(frame: CGRect())
    private var image = UIImageView(image: nil)

    private let knob = SimpleLayer()
    private let circle = SimpleShapeLayer()
    
    private var circleMaskView = UIView()
    private let maskCircle = SimpleShapeLayer()
    
    var selected: (DrawingColor) -> Void = { _ in }
                    
    private var bitmapData: UnsafeMutableRawPointer?
    
    func getColor(at point: CGPoint) -> DrawingColor? {
        guard let size = self.validSize,
              point.x >= 0 && point.x <= size.width,
              point.y >= 0 && point.y <= size.height else {
            return nil
        }
        let position = CGPoint(x: point.x / size.width, y: point.y / size.height)
        let scale = self.image.image?.scale ?? 1.0
        let point = CGPoint(x: point.x * scale, y: point.y * scale)
        guard let image = self.image.image?.cgImage else {
            return nil
        }
        
        var redComponent: CGFloat?
        var greenComponent: CGFloat?
        var blueComponent: CGFloat?
        
        let imageWidth = image.width
        let imageHeight = image.height

        let bitmapBytesForRow = Int(imageWidth * 4)
        let bitmapByteCount = bitmapBytesForRow * Int(imageHeight)
        
        if self.bitmapData == nil {
            let imageRect = CGRect(origin: .zero, size: CGSize(width: imageWidth, height: imageHeight))
                            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let bitmapData = malloc(bitmapByteCount)
            let bitmapInformation = CGImageAlphaInfo.premultipliedFirst.rawValue
            
            let colorContext = CGContext(
                data: bitmapData,
                width: imageWidth,
                height: imageHeight,
                bitsPerComponent: 8,
                bytesPerRow: bitmapBytesForRow,
                space: colorSpace,
                bitmapInfo: bitmapInformation
            )
                            
            colorContext?.clear(imageRect)
            colorContext?.draw(image, in: imageRect)
            
            self.bitmapData = bitmapData
        }
        
        self.bitmapData?.withMemoryRebound(to: UInt8.self, capacity: bitmapByteCount) { pointer in
            let offset = 4 * ((Int(imageWidth) * Int(point.y)) + Int(point.x))
            
            redComponent = CGFloat(pointer[offset + 1]) / 255.0
            greenComponent = CGFloat(pointer[offset + 2]) / 255.0
            blueComponent = CGFloat(pointer[offset + 3]) / 255.0
        }
        
        if let redComponent = redComponent, let greenComponent = greenComponent, let blueComponent = blueComponent {
            return DrawingColor(rgb: UIColor(red: redComponent, green: greenComponent, blue: blueComponent, alpha: 1.0).rgb).withUpdatedPosition(position)
        } else {
            return nil
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let bitmapData = self.bitmapData {
            free(bitmapData)
        }
    }
    
    @objc func handlePan(point: CGPoint) {
        guard let size = self.validSize else {
            return
        }
        var location = self.convert(point, from: nil)
        location.x = max(0.0, min(size.width - 1.0, location.x))
        location.y = max(0.0, min(size.height - 1.0, location.y))
        if let color = self.getColor(at: location), color != self.selectedColor {
            self.selected(color)
            let _ = self.updateLayout(size: size, selectedColor: color)
        }
    }
    
    private var animatingIn = false
    private var scheduledAnimateOut: (() -> Void)?
    
    func animateIn() {
        self.animatingIn = true
        
        Queue.mainQueue().after(0.15) {
            self.selected(DrawingColor(rgb: 0xffffff))
        }
        
        self.wrapper.mask = self.circleMaskView
        self.circleMaskView.frame = self.bounds
        
        self.maskCircle.fillColor = UIColor.red.cgColor
        self.circleMaskView.layer.addSublayer(self.maskCircle)
        
        self.maskCircle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 300.0, height: 300.0))).cgPath
        self.maskCircle.frame = CGRect(origin: .zero, size: CGSize(width: 300.0, height: 300.0))
        self.maskCircle.position = CGPoint(x: 15.0, y: self.bounds.height - 15.0)
        
        self.maskCircle.transform = CATransform3DMakeScale(3.0, 3.0, 1.0)
        self.maskCircle.animateScale(from: 0.05, to: 3.0, duration: 0.35, completion: { _ in
            self.animatingIn = false
            self.wrapper.mask = nil
            
            if let scheduledAnimateOut = self.scheduledAnimateOut {
                self.scheduledAnimateOut = nil
                self.animateOut(completion: scheduledAnimateOut)
            }
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        guard !self.animatingIn else {
            self.scheduledAnimateOut = completion
            return
        }
        
        if let selectedColor = self.selectedColor {
            self.selected(selectedColor)
        }
        
        self.knob.opacity = 0.0
        self.knob.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        
        self.circle.opacity = 0.0
        self.circle.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        
        let filler = UIView(frame: self.bounds)
        filler.backgroundColor = self.selectedColor?.toUIColor() ?? .white
        self.wrapper.addSubview(filler)
        
        filler.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        
        self.wrapper.mask = self.circleMaskView
        self.maskCircle.animatePosition(from: self.maskCircle.position, to: CGPoint(x: 16.0, y: self.bounds.height - 16.0), duration: 0.25, removeOnCompletion: false)
        self.maskCircle.animateScale(from: 3.0, to: 0.06333, duration: 0.35, removeOnCompletion: false, completion: { _ in
            
            completion()
        })
    }
        
    func updateLayout(size: CGSize, selectedColor: DrawingColor?) -> CGSize {
        let previousSize = self.validSize
        
        let imageSize = size
        self.validSize = imageSize
        
        self.selectedColor = selectedColor
                    
        if previousSize != imageSize {
            if previousSize == nil {
                self.layer.allowsGroupOpacity = true
                self.isUserInteractionEnabled = true
                self.wrapper.clipsToBounds = true
                self.wrapper.layer.cornerRadius = 17.0
            }
            
            self.wrapper.frame = CGRect(origin: .zero, size: imageSize)
            if self.wrapper.superview == nil {
                self.addSubview(self.wrapper)
            }
            
            if let bitmapData = self.bitmapData {
                free(bitmapData)
            }
            self.image.image = generateSpectrumImage(size: imageSize)
            self.image.frame = CGRect(origin: .zero, size: imageSize)
            if self.image.superview == nil {
                self.wrapper.addSubview(self.image)
            }
        }
                    
        if let color = selectedColor, let position = color.position {
            if self.knob.superlayer == nil {
                self.knob.contents = generateKnobImage()?.cgImage
                self.layer.addSublayer(self.knob)

                self.knob.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            if self.circle.superlayer == nil {
                self.circle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 26.0, height: 26.0))).cgPath
                self.layer.addSublayer(self.circle)
                
                self.circle.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            self.knob.isHidden = false
            self.circle.isHidden = false
            
            let margin: CGFloat = 10.0
            let knobSize = CGSize(width: 32.0, height: 32.0)
            let knobFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width * position.x - knobSize.width / 2.0), y: floorToScreenPixels(size.height * position.y - knobSize.height / 2.0) - 33.0), size: knobSize)
            self.knob.frame = knobFrame.insetBy(dx: -margin, dy: -margin)
            
            self.circle.fillColor = color.toUIColor().cgColor
            self.circle.frame = knobFrame.insetBy(dx: 3.0, dy: 3.0)
        } else {
            self.knob.isHidden = true
            self.circle.isHidden = true
        }
        
        return size
    }
}

private final class ColorSlidersComponent: CombinedComponent {
    typealias EnvironmentType = ComponentFlow.Empty
    
    let color: DrawingColor
    let updated: (DrawingColor) -> Void
    
    init(
        color: DrawingColor,
        updated: @escaping (DrawingColor) -> Void
    ) {
        self.color = color
        self.updated = updated
    }
    
    static func ==(lhs: ColorSlidersComponent, rhs: ColorSlidersComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    static var body: Body {
        let redTitle = Child(MultilineTextComponent.self)
        let redSlider = Child(ColorSliderComponent.self)
        let redField = Child(ColorFieldComponent.self)
        
        let greenTitle = Child(MultilineTextComponent.self)
        let greenSlider = Child(ColorSliderComponent.self)
        let greenField = Child(ColorFieldComponent.self)
        
        let blueTitle = Child(MultilineTextComponent.self)
        let blueSlider = Child(ColorSliderComponent.self)
        let blueField = Child(ColorFieldComponent.self)
        
        let hexTitle = Child(MultilineTextComponent.self)
        let hexField = Child(ColorFieldComponent.self)
        
        return { context in
            let component = context.component
            
            var contentHeight: CGFloat = 0.0
            
            let redTitle = redTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "RED",
                        font: Font.semibold(13.0),
                        textColor: UIColor(rgb: 0x9b9da5),
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(redTitle
                .position(CGPoint(x: 5.0 + redTitle.size.width / 2.0, y: contentHeight + redTitle.size.height / 2.0))
            )
            contentHeight += redTitle.size.height
            contentHeight += 8.0
            
            let currentColor = component.color
            let updateColor = component.updated
                        
            let redSlider = redSlider.update(
                component: ColorSliderComponent(
                    leftColor: component.color.withUpdatedRed(0.0).withUpdatedAlpha(1.0),
                    rightColor: component.color.withUpdatedRed(1.0).withUpdatedAlpha(1.0),
                    currentColor: component.color,
                    value: component.color.red,
                    updated: { value in
                        updateColor(currentColor.withUpdatedRed(value))
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 89.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(redSlider
                .position(CGPoint(x: redSlider.size.width / 2.0, y: contentHeight + redSlider.size.height / 2.0))
            )
            
            let redField = redField.update(
                component: ColorFieldComponent(
                    backgroundColor: UIColor(rgb: 0x000000, alpha: 0.6),
                    textColor: .white,
                    type: .number,
                    value: "\(Int(component.color.red * 255.0))",
                    updated: { value in
                        let intValue = Int(value) ?? 0
                        updateColor(currentColor.withUpdatedRed(CGFloat(intValue) / 255.0))
                    },
                    shouldUpdate: { value in
                        if let intValue = Int(value), intValue >= 0 && intValue <= 255 {
                            return true
                        } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return true
                        } else {
                            return false
                        }
                    }
                ),
                availableSize: CGSize(width: 77.0, height: 36.0),
                transition: .immediate
            )
            context.add(redField
                .position(CGPoint(x: context.availableSize.width - redField.size.width / 2.0, y: contentHeight + redField.size.height / 2.0))
            )
            
            contentHeight += redSlider.size.height
            contentHeight += 28.0
            
            let greenTitle = greenTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "GREEN",
                        font: Font.semibold(13.0),
                        textColor: UIColor(rgb: 0x9b9da5),
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(greenTitle
                .position(CGPoint(x: 5.0 + greenTitle.size.width / 2.0, y: contentHeight + greenTitle.size.height / 2.0))
            )
            contentHeight += greenTitle.size.height
            contentHeight += 8.0
            
            let greenSlider = greenSlider.update(
                component: ColorSliderComponent(
                    leftColor: component.color.withUpdatedGreen(0.0).withUpdatedAlpha(1.0),
                    rightColor: component.color.withUpdatedGreen(1.0).withUpdatedAlpha(1.0),
                    currentColor: component.color,
                    value: component.color.green,
                    updated: { value in
                        updateColor(currentColor.withUpdatedGreen(value))
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 89.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(greenSlider
                .position(CGPoint(x: greenSlider.size.width / 2.0, y: contentHeight + greenSlider.size.height / 2.0))
            )
            
            let greenField = greenField.update(
                component: ColorFieldComponent(
                    backgroundColor: UIColor(rgb: 0x000000, alpha: 0.6),
                    textColor: .white,
                    type: .number,
                    value: "\(Int(component.color.green * 255.0))",
                    updated: { value in
                        let intValue = Int(value) ?? 0
                        updateColor(currentColor.withUpdatedGreen(CGFloat(intValue) / 255.0))
                    },
                    shouldUpdate: { value in
                        if let intValue = Int(value), intValue >= 0 && intValue <= 255 {
                            return true
                        } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return true
                        } else {
                            return false
                        }
                    }
                ),
                availableSize: CGSize(width: 77.0, height: 36.0),
                transition: .immediate
            )
            context.add(greenField
                .position(CGPoint(x: context.availableSize.width - greenField.size.width / 2.0, y: contentHeight + greenField.size.height / 2.0))
            )
            
            contentHeight += greenSlider.size.height
            contentHeight += 28.0
            
            let blueTitle = blueTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "BLUE",
                        font: Font.semibold(13.0),
                        textColor: UIColor(rgb: 0x9b9da5),
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(blueTitle
                .position(CGPoint(x: 5.0 + blueTitle.size.width / 2.0, y: contentHeight + blueTitle.size.height / 2.0))
            )
            contentHeight += blueTitle.size.height
            contentHeight += 8.0
            
            let blueSlider = blueSlider.update(
                component: ColorSliderComponent(
                    leftColor: component.color.withUpdatedBlue(0.0).withUpdatedAlpha(1.0),
                    rightColor: component.color.withUpdatedBlue(1.0).withUpdatedAlpha(1.0),
                    currentColor: component.color,
                    value: component.color.blue,
                    updated: { value in
                        updateColor(currentColor.withUpdatedBlue(value))
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 89.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(blueSlider
                .position(CGPoint(x: blueSlider.size.width / 2.0, y: contentHeight + blueSlider.size.height / 2.0))
            )
            
            let blueField = blueField.update(
                component: ColorFieldComponent(
                    backgroundColor: UIColor(rgb: 0x000000, alpha: 0.6),
                    textColor: .white,
                    type: .number,
                    value: "\(Int(component.color.blue * 255.0))",
                    updated: { value in
                        let intValue = Int(value) ?? 0
                        updateColor(currentColor.withUpdatedBlue(CGFloat(intValue) / 255.0))
                    },
                    shouldUpdate: { value in
                        if let intValue = Int(value), intValue >= 0 && intValue <= 255 {
                            return true
                        } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return true
                        } else {
                            return false
                        }
                    }
                ),
                availableSize: CGSize(width: 77.0, height: 36.0),
                transition: .immediate
            )
            context.add(blueField
                .position(CGPoint(x: context.availableSize.width - blueField.size.width / 2.0, y: contentHeight + blueField.size.height / 2.0))
            )
            
            contentHeight += blueSlider.size.height
            contentHeight += 28.0
            
            let hexField = hexField.update(
                component: ColorFieldComponent(
                    backgroundColor: UIColor(rgb: 0x000000, alpha: 0.6),
                    textColor: .white,
                    type: .text,
                    value: component.color.toUIColor().hexString.uppercased(),
                    updated: { value in
                        if value.count == 6, let uiColor = UIColor(hexString: value) {
                            updateColor(DrawingColor(color: uiColor).withUpdatedAlpha(currentColor.alpha))
                        }
                    },
                    shouldUpdate: { value in
                        if value.count <= 6 && value.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil {
                            return true
                        } else {
                            return false
                        }
                    }
                ),
                availableSize: CGSize(width: 77.0, height: 36.0),
                transition: .immediate
            )
            context.add(hexField
                .position(CGPoint(x: context.availableSize.width - hexField.size.width / 2.0, y: contentHeight + hexField.size.height / 2.0))
            )
                        
            let hexTitle = hexTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "Hex Color #",
                        font: Font.regular(17.0),
                        textColor: UIColor(rgb: 0xffffff),
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(hexTitle
                .position(CGPoint(x: context.availableSize.width - hexField.size.width - 12.0 - hexTitle.size.width / 2.0, y: contentHeight + hexField.size.height / 2.0))
            )
            
            contentHeight += hexField.size.height
            contentHeight += 8.0
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private class SegmentedControlComponent: Component {
    let values: [String]
    let selectedIndex: Int
    let selectionChanged: (Int) -> Void
    
    init(values: [String], selectedIndex: Int, selectionChanged: @escaping (Int) -> Void) {
        self.values = values
        self.selectedIndex = selectedIndex
        self.selectionChanged = selectionChanged
    }
    
    static func ==(lhs: SegmentedControlComponent, rhs: SegmentedControlComponent) -> Bool {
        if lhs.values != rhs.values {
            return false
        }
        if lhs.selectedIndex != rhs.selectedIndex {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundNode: NavigationBackgroundNode
        private let node: SegmentedControlNode

        init() {
            self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x888888, alpha: 0.1))
            self.node = SegmentedControlNode(theme: SegmentedControlTheme(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0x6f7075, alpha: 0.6), shadowColor: .black, textColor: UIColor(rgb: 0xffffff), dividerColor: UIColor(rgb: 0x505155, alpha: 0.6)), items: [], selectedIndex: 0)

            super.init(frame: CGRect())

            self.addSubview(self.backgroundNode.view)
            self.addSubview(self.node.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: SegmentedControlComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.node.items = component.values.map { SegmentedControlItem(title: $0) }
            self.node.selectedIndex = component.selectedIndex
            let selectionChanged = component.selectionChanged
            self.node.selectedIndexChanged = { [weak self] index in
                self?.window?.endEditing(true)
                selectionChanged(index)
            }
            
            let size = self.node.updateLayout(.stretchToFill(width: availableSize.width), transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.node.view, frame: CGRect(origin: CGPoint(), size: size))
            
            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundNode.update(size: size, cornerRadius: 10.0, transition: .immediate)
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class ColorSwatchComponent: Component {
    enum SwatchType: Equatable {
        case main
        case pallete(Bool)
    }
    
    let type: SwatchType
    let color: DrawingColor?
    let tag: AnyObject?
    let action: () -> Void
    let holdAction: (() -> Void)?
    let pan: ((CGPoint) -> Void)?
    let release: (() -> Void)?
    
    init(
        type: SwatchType,
        color: DrawingColor?,
        tag: AnyObject? = nil,
        action: @escaping () -> Void,
        holdAction: (() -> Void)? = nil,
        pan: ((CGPoint) -> Void)? = nil,
        release: (() -> Void)? = nil
    ) {
        self.type = type
        self.color = color
        self.tag = tag
        self.action = action
        self.holdAction = holdAction
        self.pan = pan
        self.release = release
    }
    
    static func == (lhs: ColorSwatchComponent, rhs: ColorSwatchComponent) -> Bool {
        return lhs.type == rhs.type && lhs.color == rhs.color
    }
    
    final class View: UIButton, ComponentTaggedView {
        private var component: ColorSwatchComponent?
        
        private var contentView: UIView
        
        private var ringLayer: CALayer?
        private var ringMaskLayer: SimpleShapeLayer?
    
        private let circleLayer: SimpleShapeLayer
        
        private let fastCircleLayer: SimpleShapeLayer
        
        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.contentView.alpha = self.currentIsHighlighted ? 0.6 : 1.0
                }
            }
        }
        
        private var holdActionTriggerred: Bool = false
        private var holdActionTimer: Foundation.Timer?
        
        override init(frame: CGRect) {
            self.contentView = UIView(frame: CGRect(origin: .zero, size: frame.size))
            self.contentView.isUserInteractionEnabled = false
            self.circleLayer = SimpleShapeLayer()
            self.fastCircleLayer = SimpleShapeLayer()
            self.fastCircleLayer.fillColor = UIColor.white.cgColor
            self.fastCircleLayer.isHidden = true
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            self.contentView.layer.addSublayer(self.circleLayer)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        @objc private func pressed() {
            if self.holdActionTriggerred {
                self.holdActionTriggerred = false
            } else {
                self.component?.action()
            }
        }
        
        override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            self.holdActionTriggerred = false
            
            if self.component?.holdAction != nil {
                Queue.mainQueue().after(0.15, {
                    if self.currentIsHighlighted {
                        self.fastCircleLayer.isHidden = false
                        self.fastCircleLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        self.fastCircleLayer.animateScale(from: 0.57575, to: 1.0, duration: 0.25)
                    }
                })
                
                self.holdActionTimer?.invalidate()
                if #available(iOS 10.0, *) {
                    let holdActionTimer = Timer(timeInterval: 0.4, repeats: false, block: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.holdActionTriggerred = true
                        strongSelf.holdActionTimer?.invalidate()
                        strongSelf.component?.holdAction?()
                        Queue.mainQueue().after(0.1, {
                            strongSelf.fastCircleLayer.isHidden = true
                        })
                    })
                    self.holdActionTimer = holdActionTimer
                    RunLoop.main.add(holdActionTimer, forMode: .common)
                }
            }
            
            return super.beginTracking(touch, with: event)
        }
        
        override public func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            if self.holdActionTriggerred {
                let location = touch.location(in: nil)
                self.component?.pan?(location)
            }
            return true
        }
                
        override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            if self.holdActionTriggerred {
                self.component?.release?()
            }
            
            self.currentIsHighlighted = false
            Queue.mainQueue().after(0.1) {
                self.holdActionTriggerred = false
            }
            if !self.fastCircleLayer.isHidden {
                let currentAlpha: CGFloat = CGFloat(self.fastCircleLayer.presentation()?.opacity ?? 1.0)
                self.fastCircleLayer.animateAlpha(from: currentAlpha, to: 0.0, duration: 0.1, completion: { _ in
                    self.fastCircleLayer.isHidden = true
                })
            }
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
            super.endTracking(touch, with: event)
        }
        
        override public func cancelTracking(with event: UIEvent?) {
            if self.holdActionTriggerred {
                self.component?.release?()
            }
            
            self.currentIsHighlighted = false
            self.holdActionTriggerred = false
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
            super.cancelTracking(with: event)
        }
        
        func animateIn() {
            self.contentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.contentView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3)
        }
        
        func animateOut() {
            self.contentView.alpha = 0.0
            self.contentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            self.contentView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
        }
        
        func update(component: ColorSwatchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            let contentSize: CGSize
            if case .pallete = component.type {
                contentSize = availableSize
            } else {
                contentSize = CGSize(width: 24.0, height: 24.0)
            }
            self.contentView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - contentSize.width) / 2.0), y: floor((availableSize.height - contentSize.height) / 2.0)), size: contentSize)
            
            let bounds = CGRect(origin: .zero, size: contentSize)
            switch component.type {
            case .main:
                self.circleLayer.frame = bounds
                if self.circleLayer.path == nil {
                    self.circleLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 3.0, dy: 3.0)).cgPath
                }
            
                let ringFrame = bounds.insetBy(dx: -1.0, dy: -1.0)
                if self.ringLayer == nil {
                    let ringLayer = SimpleLayer()
                    ringLayer.contents = UIImage(bundleImageName: "Media Editor/RoundSpectrum")?.cgImage
                    ringLayer.frame = ringFrame
                    self.contentView.layer.addSublayer(ringLayer)
                    
                    self.ringLayer = ringLayer
                    
                    let ringMaskLayer = SimpleShapeLayer()
                    ringMaskLayer.frame = CGRect(origin: .zero, size: ringFrame.size)
                    ringMaskLayer.strokeColor = UIColor.white.cgColor
                    ringMaskLayer.fillColor = UIColor.clear.cgColor
                    self.ringMaskLayer = ringMaskLayer
                    self.ringLayer?.mask = ringMaskLayer
                }
            
                if let ringMaskLayer = self.ringMaskLayer {
                    if component.color == nil {
                        transition.setShapeLayerPath(layer: ringMaskLayer, path: UIBezierPath(ovalIn: CGRect(origin: .zero, size: ringFrame.size).insetBy(dx: 7.0, dy: 7.0)).cgPath)
                        transition.setShapeLayerLineWidth(layer: ringMaskLayer, lineWidth: 12.0)
                    } else {
                        transition.setShapeLayerPath(layer: ringMaskLayer, path: UIBezierPath(ovalIn: CGRect(origin: .zero, size: ringFrame.size).insetBy(dx: 1.0, dy: 1.0)).cgPath)
                        transition.setShapeLayerLineWidth(layer: ringMaskLayer, lineWidth: 2.0)
                    }
                }
                
                if self.fastCircleLayer.path == nil {
                    self.fastCircleLayer.path = UIBezierPath(ovalIn: bounds).cgPath
                    self.fastCircleLayer.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - bounds.size.width) / 2.0), y: floorToScreenPixels((availableSize.height - bounds.size.height) / 2.0)), size: bounds.size)
                    self.layer.addSublayer(self.fastCircleLayer)
                }
            case let .pallete(selected):
                self.layer.allowsGroupOpacity = true
                self.contentView.layer.allowsGroupOpacity = true
                
                self.circleLayer.frame = bounds
                if self.ringLayer == nil {
                    let ringLayer = SimpleLayer()
                    ringLayer.backgroundColor = UIColor.clear.cgColor
                    ringLayer.cornerRadius = contentSize.width / 2.0
                    ringLayer.borderWidth = 3.0
                    ringLayer.frame = CGRect(origin: .zero, size: contentSize)
                    self.contentView.layer.insertSublayer(ringLayer, at: 0)
                    self.ringLayer = ringLayer
                }

                if selected {
                    transition.setShapeLayerPath(layer: self.circleLayer, path: CGPath(ellipseIn: bounds.insetBy(dx: 5.0, dy: 5.0), transform: nil))
                } else {
                    transition.setShapeLayerPath(layer: self.circleLayer, path: CGPath(ellipseIn: bounds, transform: nil))
                }
            }
            
            if let color = component.color {
                self.circleLayer.fillColor = color.toCGColor()
                if case .pallete = component.type {
                    if color.toUIColor().rgb == 0x000000 {
                        self.circleLayer.strokeColor = UIColor(rgb: 0x1f1f1f).cgColor
                        self.circleLayer.lineWidth = 1.0
                        self.ringLayer?.borderColor = UIColor(rgb: 0x1f1f1f).cgColor
                    } else {
                        self.ringLayer?.borderColor = color.toCGColor()
                    }
                }
            }
            
            if let screenTransition = transition.userData(DrawingScreenTransition.self) {
                switch screenTransition {
                case .animateIn:
                    self.animateIn()
                case .animateOut:
                    self.animateOut()
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


class BlurredRectangle: Component {
    let color: UIColor
    let radius: CGFloat

    init(color: UIColor, radius: CGFloat = 0.0) {
        self.color = color
        self.radius = radius
    }

    static func ==(lhs: BlurredRectangle, rhs: BlurredRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.radius != rhs.radius {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background: NavigationBackgroundNode

        init() {
            self.background = NavigationBackgroundNode(color: .clear)

            super.init(frame: CGRect())

            self.addSubview(self.background.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BlurredRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            transition.setFrame(view: self.background.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.background.updateColor(color: component.color, transition: .immediate)
            self.background.update(size: availableSize, cornerRadius: component.radius, transition: .immediate)

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class ColorPickerContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialColor: DrawingColor
    let colorChanged: (DrawingColor) -> Void
    let eyedropper: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        initialColor: DrawingColor,
        colorChanged: @escaping (DrawingColor) -> Void,
        eyedropper: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.initialColor = initialColor
        self.colorChanged = colorChanged
        self.eyedropper = eyedropper
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ColorPickerContent, rhs: ColorPickerContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedEyedropperImage: UIImage?
        var eyedropperImage: UIImage {
            let eyedropperImage: UIImage
            if let image = self.cachedEyedropperImage {
                eyedropperImage = image
            } else {
                eyedropperImage = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Eyedropper"), color: .white)!
                self.cachedEyedropperImage = eyedropperImage
            }
            return eyedropperImage
        }
        
        var cachedCloseImage: UIImage?
        var closeImage: UIImage {
            let closeImage: UIImage
            if let image = self.cachedCloseImage {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xa8aab1))!
                self.cachedCloseImage = closeImage
            }
            return closeImage
        }
        
        var selectedMode: Int = 0
        var selectedColor: DrawingColor
        
        var savedColors: [DrawingColor] = []
        
        var colorChanged: (DrawingColor) -> Void = { _ in }
        
        init(initialColor: DrawingColor) {
            self.selectedColor = initialColor
            
            self.savedColors = [DrawingColor(color: .red), DrawingColor(color: .green), DrawingColor(color: .blue)]
        }
        
        func updateColor(_ color: DrawingColor, keepAlpha: Bool = false) {
            self.selectedColor = keepAlpha ? color.withUpdatedAlpha(self.selectedColor.alpha) : color
            self.colorChanged(self.selectedColor)
            self.updated(transition: .immediate)
        }
        
        func updateAlpha(_ alpha: CGFloat) {
            self.selectedColor = self.selectedColor.withUpdatedAlpha(alpha)
            self.colorChanged(self.selectedColor)
            self.updated(transition: .immediate)
        }
        
        func updateSelectedMode(_ mode: Int) {
            self.selectedMode = mode
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func saveCurrentColor() {
            self.savedColors.append(self.selectedColor)
            self.updated(transition: .easeInOut(duration: 0.2))
        }
    }
    
    func makeState() -> State {
        return State(initialColor: self.initialColor)
    }
    
    static var body: Body {
        let eyedropperButton = Child(Button.self)
        let closeButton = Child(Button.self)
        let title = Child(MultilineTextComponent.self)
        let modeControl = Child(SegmentedControlComponent.self)
        
        let colorGrid = Child(ColorGridComponent.self)
        let colorSpectrum = Child(ColorSpectrumComponent.self)
        let colorSliders = Child(ColorSlidersComponent.self)
        
        let opacityTitle = Child(MultilineTextComponent.self)
        let opacitySlider = Child(ColorSliderComponent.self)
        let opacityField = Child(ColorFieldComponent.self)
        
        let divider = Child(Rectangle.self)
        
        let preview = Child(ColorPreviewComponent.self)
        
        let swatch1Button = Child(ColorSwatchComponent.self)
        let swatch2Button = Child(ColorSwatchComponent.self)
        let swatch3Button = Child(ColorSwatchComponent.self)
        let swatch4Button = Child(ColorSwatchComponent.self)
        let swatch5Button = Child(ColorSwatchComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            state.colorChanged = component.colorChanged
            
            let sideInset: CGFloat = 16.0
                        
            let eyedropperButton = eyedropperButton.update(
                component: Button(
                    content: AnyComponent(
                        Image(image: state.eyedropperImage)
                    ),
                    action: { [weak component] in
                        component?.eyedropper()
                    }
                ).minSize(CGSize(width: 30.0, height: 30.0)),
                availableSize: CGSize(width: 19.0, height: 19.0),
                transition: .immediate
            )
            context.add(eyedropperButton
                .position(CGPoint(x: environment.safeInsets.left + eyedropperButton.size.width + 1.0, y: 29.0))
            )
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(
                            id: "background",
                            component: AnyComponent(
                                BlurredRectangle(
                                    color:  UIColor(rgb: 0x888888, alpha: 0.1),
                                    radius: 15.0
                                )
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(
                                Image(image: state.closeImage)
                            )
                        ),
                    ])),
                    action: { [weak component] in
                        component?.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - closeButton.size.width - 1.0, y: 29.0))
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "Colors",
                        font: Font.semibold(17.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - 100.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 29.0))
            )
            
            var contentHeight: CGFloat = 58.0
            
            let modeControl = modeControl.update(
                component: SegmentedControlComponent(
                    values: ["Grid", "Spectrum", "Sliders"],
                    selectedIndex: 0,
                    selectionChanged: { [weak state] index in
                        state?.updateSelectedMode(index)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(modeControl
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + modeControl.size.height / 2.0))
            )
            contentHeight += modeControl.size.height
            contentHeight += 20.0
            
            let squareSize = floorToScreenPixels((context.availableSize.width - sideInset * 2.0) / 12.0)
            let fieldSize = CGSize(width: context.availableSize.width - sideInset * 2.0, height: squareSize * 10.0)
            
            if state.selectedMode == 0 {
                let colorGrid = colorGrid.update(
                    component: ColorGridComponent(
                        color: state.selectedColor,
                        selected: { [weak state] color in
                            state?.updateColor(color, keepAlpha: true)
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(colorGrid
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + colorGrid.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default())
                )
            } else if state.selectedMode == 1 {
                let colorSpectrum = colorSpectrum.update(
                    component: ColorSpectrumComponent(
                        color: state.selectedColor,
                        selected: { [weak state] color in
                            state?.updateColor(color, keepAlpha: true)
                        }
                    ),
                    availableSize: fieldSize,
                    transition: .immediate
                )
                context.add(colorSpectrum
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + fieldSize.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default())
                )
            } else if state.selectedMode == 2 {
                let colorSliders = colorSliders.update(
                    component: ColorSlidersComponent(
                        color: state.selectedColor,
                        updated: { [weak state] color in
                            state?.updateColor(color, keepAlpha: true)
                        }
                    ),
                    availableSize: fieldSize,
                    transition: .immediate
                )
                context.add(colorSliders
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + colorSliders.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default())
                )
            }
            
            contentHeight += fieldSize.height
            contentHeight += 21.0
            
            let opacityTitle = opacityTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "OPACITY",
                        font: Font.semibold(13.0),
                        textColor: UIColor(rgb: 0x9b9da5),
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(opacityTitle
                .position(CGPoint(x: sideInset + 5.0 + opacityTitle.size.width / 2.0, y: contentHeight + opacityTitle.size.height / 2.0))
            )
            contentHeight += opacityTitle.size.height
            contentHeight += 8.0
            
            let opacitySlider = opacitySlider.update(
                component: ColorSliderComponent(
                    leftColor: state.selectedColor.withUpdatedAlpha(0.0),
                    rightColor: state.selectedColor.withUpdatedAlpha(1.0),
                    currentColor: state.selectedColor,
                    value: state.selectedColor.alpha,
                    updated: { value in
                        state.updateAlpha(value)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 89.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(opacitySlider
                .position(CGPoint(x: sideInset + opacitySlider.size.width / 2.0, y: contentHeight + opacitySlider.size.height / 2.0))
            )
            
            let opacityField = opacityField.update(
                component: ColorFieldComponent(
                    backgroundColor: UIColor(rgb: 0x000000, alpha: 0.6),
                    textColor: .white,
                    type: .number,
                    value: "\(Int(state.selectedColor.alpha * 100.0))",
                    suffix: "%",
                    updated: { value in
                        let intValue = Int(value) ?? 0
                        state.updateAlpha(CGFloat(intValue) / 100.0)
                    },
                    shouldUpdate: { value in
                        if let intValue = Int(value), intValue >= 0 && intValue <= 100 {
                            return true
                        } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return true
                        } else {
                            return false
                        }
                    }
                ),
                availableSize: CGSize(width: 77.0, height: 36.0),
                transition: .immediate
            )
            context.add(opacityField
                .position(CGPoint(x: context.availableSize.width - sideInset - opacityField.size.width / 2.0, y: contentHeight + opacityField.size.height / 2.0))
            )
            
            contentHeight += opacitySlider.size.height
            contentHeight += 24.0
            
            let divider = divider.update(
                component: Rectangle(color: UIColor(rgb: 0x48484a)),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 1.0),
                transition: .immediate
            )
            context.add(divider
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight))
            )
            contentHeight += divider.size.height
            contentHeight += 22.0
                         
            let preview = preview.update(
                component: ColorPreviewComponent(
                    color: state.selectedColor
                ),
                availableSize: CGSize(width: 82.0, height: 82.0),
                transition: .immediate
            )
            context.add(preview
                .position(CGPoint(x: sideInset + preview.size.width / 2.0, y: contentHeight + preview.size.height / 2.0))
            )
          
            
            var swatchOffset: CGFloat = sideInset + preview.size.width + 38.0
            let swatchSpacing: CGFloat = 20.0
            
            let swatch1Button = swatch1Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(state.selectedColor == DrawingColor(color: .black)),
                    color: DrawingColor(color: .black),
                    action: {
                        state.updateColor(DrawingColor(color: .black))
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
            context.add(swatch1Button
                .position(CGPoint(x: swatchOffset, y: contentHeight + swatch1Button.size.height / 2.0))
            )
            swatchOffset += swatch1Button.size.width + swatchSpacing
        
            let swatch2Button = swatch2Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(state.selectedColor == DrawingColor(rgb: 0x0161fd)),
                    color: DrawingColor(rgb: 0x0161fd),
                    action: {
                        state.updateColor(DrawingColor(rgb: 0x0161fd))
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
            context.add(swatch2Button
                .position(CGPoint(x: swatchOffset, y: contentHeight + swatch2Button.size.height / 2.0))
            )
            swatchOffset += swatch2Button.size.width + swatchSpacing
            
            let swatch3Button = swatch3Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(state.selectedColor == DrawingColor(rgb: 0x32c759)),
                    color: DrawingColor(rgb: 0x32c759),
                    action: {
                        state.updateColor(DrawingColor(rgb: 0x32c759))
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
            context.add(swatch3Button
                .position(CGPoint(x: swatchOffset, y: contentHeight + swatch3Button.size.height / 2.0))
            )
            swatchOffset += swatch3Button.size.width + swatchSpacing
            
            let swatch4Button = swatch4Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(state.selectedColor == DrawingColor(rgb: 0xffcc02)),
                    color: DrawingColor(rgb: 0xffcc02),
                    action: {
                        state.updateColor(DrawingColor(rgb: 0xffcc02))
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
            context.add(swatch4Button
                .position(CGPoint(x: swatchOffset, y: contentHeight + swatch4Button.size.height / 2.0))
            )
            swatchOffset += swatch4Button.size.width + swatchSpacing
            
            let swatch5Button = swatch5Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(state.selectedColor == DrawingColor(rgb: 0xff3a30)),
                    color: DrawingColor(rgb: 0xff3a30),
                    action: {
                        state.updateColor(DrawingColor(rgb: 0xff3a30))
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
            context.add(swatch5Button
                .position(CGPoint(x: swatchOffset, y: contentHeight + swatch5Button.size.height / 2.0))
            )
            
            contentHeight += preview.size.height
            contentHeight += 10.0
            
            let bottomPanelPadding: CGFloat = 12.0
            var bottomInset: CGFloat
            if case .regular = environment.metrics.widthClass {
                bottomInset = bottomPanelPadding
            } else {
                bottomInset = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            }
            
            if environment.inputHeight > 0.0 {
                bottomInset += environment.inputHeight - bottomInset - 120.0
            }
            
            return CGSize(width: context.availableSize.width, height: contentHeight + bottomInset)
        }
    }
}

private final class ColorPickerSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let initialColor: DrawingColor
    private let updated: (DrawingColor) -> Void
    private let openEyedropper: () -> Void
    private let dismissed: () -> Void
    
    init(context: AccountContext, initialColor: DrawingColor, updated: @escaping (DrawingColor) -> Void, openEyedropper: @escaping () -> Void, dismissed: @escaping () -> Void) {
        self.context = context
        self.initialColor = initialColor
        self.updated = updated
        self.openEyedropper = openEyedropper
        self.dismissed = dismissed
    }
    
    static func ==(lhs: ColorPickerSheetComponent, rhs: ColorPickerSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let updated = context.component.updated
            let openEyedropper = context.component.openEyedropper
            let dismissed = context.component.dismissed
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(ColorPickerContent(
                        context: context.component.context,
                        initialColor: context.component.initialColor,
                        colorChanged: { color in
                            updated(color)
                        },
                        eyedropper: {
                            openEyedropper()
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
                        dismiss: {
                            dismissed()
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .blur(.dark),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

class ColorPickerScreen: ViewControllerComponentContainer {
    init(context: AccountContext, initialColor: DrawingColor, updated: @escaping (DrawingColor) -> Void, openEyedropper: @escaping () -> Void, dismissed: @escaping () -> Void = {}) {
        super.init(context: context, component: ColorPickerSheetComponent(context: context, initialColor: initialColor, updated: updated, openEyedropper: openEyedropper, dismissed: dismissed), navigationBarAppearance: .none)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationPresentation = .flatModal
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
