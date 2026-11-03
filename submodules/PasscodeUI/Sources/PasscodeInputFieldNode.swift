import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

private let dotDiameter: CGFloat = 13.0
private let dotSpacing: CGFloat = 24.0
private let fieldHeight: CGFloat = 38.0

private func generateDotImage(color: UIColor, filled: Bool) -> UIImage? {
    return generateImage(CGSize(width: dotDiameter, height: dotDiameter), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        if filled {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: bounds)
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: bounds.insetBy(dx: 0.5, dy: 0.5))
        }
    })
}

private func generateFieldBackgroundImage(backgroundImage: UIImage?, backgroundSize: CGSize?, frame: CGRect) -> UIImage? {
    return generateImage(frame.size, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height), cornerRadius: 6.0)
        context.addPath(path.cgPath)
        context.clip()
        
        if let backgroundImage = backgroundImage, let backgroundSize = backgroundSize {
            let relativeFrame = CGRect(x: -frame.minX, y: frame.minY - backgroundSize.height + frame.size.height
                , width: backgroundSize.width, height: backgroundSize.height)
            context.draw(backgroundImage.cgImage!, in: relativeFrame)
        } else {
            context.setFillColor(UIColor(rgb: 0xffffff, alpha: 1.0).cgColor)
            context.fill(bounds)
        }
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
    
        let innerPath = UIBezierPath(roundedRect: CGRect(x: 1.0, y: 1.0, width: size.width - 2.0, height: size.height - 2.0), cornerRadius: 6.0)
        context.addPath(innerPath.cgPath)
        context.fillPath()
    })
}

private let validDigitsSet: CharacterSet = {
    return CharacterSet(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
}()

public enum PasscodeEntryFieldType {
    case digits6
    case digits4
    case alphanumeric
    
    public var maxLength: Int? {
        switch self {
            case .digits6:
                return 6
            case .digits4:
                return 4
            case .alphanumeric:
                return nil
        }
    }
    
    public var allowedCharacters: CharacterSet? {
        switch self {
            case .digits6, .digits4:
                return validDigitsSet
            case .alphanumeric:
                return nil
        }
    }
    
    public var keyboardType: UIKeyboardType {
        switch self {
            case .digits6, .digits4:
                if #available(iOS 10.0, *) {
                    return .asciiCapableNumberPad
                } else {
                    return .numberPad
                }
            case .alphanumeric:
                return .default
        }
    }
}

private class PasscodeEntryInputView: UIView {
    
}

private class PasscodeEntryDotNode: ASImageNode {
    private let regularImage: UIImage
    private let filledImage: UIImage
    private var currentImage: UIImage
    
    init(color: UIColor) {
        self.regularImage = generateDotImage(color: color, filled: false)!
        self.filledImage = generateDotImage(color: color, filled: true)!
        self.currentImage = self.regularImage
        
        super.init()
        
        self.image = self.currentImage
    }
    
    func updateState(filled: Bool, animated: Bool = false, delay: Double = 0.0) {
        let image = filled ? self.filledImage : self.regularImage
        if self.currentImage !== image {
            let currentContents = self.layer.contents
            self.layer.removeAnimation(forKey: "contents")
            if let currentContents = currentContents, animated {
                self.layer.animate(from: currentContents as AnyObject, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: image === self.regularImage ? 0.25 : 0.05, delay: delay, removeOnCompletion: false, completion: { finished in
                    if finished {
                        self.image = image
                    }
                })
            } else {
                self.image = image
            }
            self.currentImage = image
        }
    }
}

public final class PasscodeInputFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var background: PasscodeBackground?
    private var color: UIColor
    private var accentColor: UIColor
    private var fieldType: PasscodeEntryFieldType
    private var useCustomNumpad: Bool
    private let fieldBackgroundColor: UIColor?
    
    private let textFieldNode: TextFieldNode
    private let borderNode: ASImageNode
    private let dotNodes: [PasscodeEntryDotNode]
    
    private var validLayout: (CGSize, CGFloat)?
    
    public var complete: ((String) -> Void)?
    private var inputGeneration: Int = 0
    var isInputEnabled = true {
        didSet {
            if self.isInputEnabled != oldValue {
                self.cancelPendingCompletion()
            }
        }
    }
    
    public var text: String {
        return self.textFieldNode.textField.text ?? ""
    }
    
    public var keyboardAppearance: UIKeyboardAppearance {
        didSet {
            self.textFieldNode.textField.keyboardAppearance = self.keyboardAppearance
        }
    }
    
    public init(color: UIColor, accentColor: UIColor, fieldType: PasscodeEntryFieldType, keyboardAppearance: UIKeyboardAppearance, useCustomNumpad: Bool = false, fieldBackgroundColor: UIColor? = nil) {
        self.color = color
        self.accentColor = accentColor
        self.fieldType = fieldType
        self.keyboardAppearance = keyboardAppearance
        self.useCustomNumpad = useCustomNumpad
        self.fieldBackgroundColor = fieldBackgroundColor
        
        self.textFieldNode = TextFieldNode()
        self.borderNode = ASImageNode()
        self.dotNodes = (0 ..< 6).map { _ in PasscodeEntryDotNode(color: color) }
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        for node in self.dotNodes {
            self.addSubnode(node)
        }
        self.addSubnode(self.borderNode)
        self.addSubnode(self.textFieldNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.textFieldNode.textField.isSecureTextEntry = true
        self.textFieldNode.textField.textColor = self.color
        self.textFieldNode.textField.delegate = self
        self.textFieldNode.textField.returnKeyType = .done
        self.textFieldNode.textField.tintColor = self.accentColor
        self.textFieldNode.textField.keyboardAppearance = self.keyboardAppearance
        self.textFieldNode.textField.keyboardType = self.fieldType.keyboardType
        self.textFieldNode.textField.tintColor = self.accentColor
        
        self.updateKeyboard()
    }

    private func updateKeyboard() {
        let textField = self.textFieldNode.textField
        textField.keyboardType = self.fieldType.keyboardType
        if self.useCustomNumpad && self.fieldType != .alphanumeric {
            if textField.inputView == nil {
                textField.inputView = PasscodeEntryInputView()
            }
        } else {
            textField.inputView = nil
        }
        if textField.isFirstResponder {
            textField.reloadInputViews()
        }
    }

    func updateFieldType(_ fieldType: PasscodeEntryFieldType, animated: Bool, useCustomNumpad: Bool? = nil) {
        self.cancelPendingCompletion()
        self.fieldType = fieldType
        if let useCustomNumpad {
            self.useCustomNumpad = useCustomNumpad
        }
        self.updateKeyboard()
        
        if let (size, topOffset) = self.validLayout {
            let _ = self.updateLayout(size: size, topOffset: topOffset, transition: animated ? .animated(duration: 0.25, curve: .easeInOut) : .immediate)
        }
    }
    
    func updateBackground(_ background: PasscodeBackground) {
        self.background = background
        if let (size, topOffset) = self.validLayout {
            let _ = self.updateLayout(size: size, topOffset: topOffset, transition: .immediate)
        }
    }
    
    public func activateInput() {
        self.textFieldNode.textField.becomeFirstResponder()
    }
    
    func animateIn() {
        switch self.fieldType {
            case .digits6, .digits4:
                for node in self.dotNodes {
                    node.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                }
            case .alphanumeric:
                self.textFieldNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                self.borderNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        }
    }
    
    func animateSuccess() {
        switch self.fieldType {
            case .digits6, .digits4:
                var delay: Double = 0.0
                for node in self.dotNodes {
                    node.updateState(filled: true, animated: true, delay: delay)
                    delay += 0.01
                }
            case .alphanumeric:
                if (self.textFieldNode.textField.text ?? "").isEmpty {
                    self.textFieldNode.textField.text = "passwordpassword"
                }
        }
    }
    
    public func reset(animated: Bool = true) {
        self.cancelPendingCompletion()
        var delay: Double = 0.0
        for node in self.dotNodes.reversed() {
            if node.alpha < 1.0 {
                continue
            }
            
            node.updateState(filled: false, animated: animated, delay: delay)
            delay += 0.05
        }
        self.textFieldNode.textField.text = ""
    }
    
    func append(_ string: String) {
        guard self.isInputEnabled, !string.isEmpty else { return }
        let text = (self.textFieldNode.textField.text ?? "") + string
        let maxLength = self.fieldType.maxLength
        if let maxLength = maxLength, text.count > maxLength {
            return
        }
        if let allowedCharacters = self.fieldType.allowedCharacters, text.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return
        }
        self.cancelPendingCompletion()
        self.textFieldNode.textField.text = text
        self.updateDots(count: text.count, animated: false)
        
        if let maxLength = maxLength, text.count == maxLength {
            self.scheduleCompletion(text)
        }
    }
    
    func delete() -> Bool {
        guard self.isInputEnabled else { return false }
        self.cancelPendingCompletion()
        var text = self.textFieldNode.textField.text ?? ""
        guard !text.isEmpty else {
            return false
        }
        text = String(text[text.startIndex ..< text.index(text.endIndex, offsetBy: -1)])
        self.textFieldNode.textField.text = text
        self.updateDots(count: text.count, animated: true)
        return true
    }
    
    func updateDots(count: Int, animated: Bool) {
        var i = -1
        for node in self.dotNodes {
            if node.alpha < 1.0 {
                continue
            }
            i += 1
            node.updateState(filled: i < count, animated: animated)
        }
    }
    
    public func update(fieldType: PasscodeEntryFieldType) {
        self.cancelPendingCompletion()
        if fieldType != self.fieldType {
            self.textFieldNode.textField.text = ""
        }
        self.fieldType = fieldType
        self.updateKeyboard()
        if let (size, topOffset) = self.validLayout {
            let _ = self.updateLayout(size: size, topOffset: topOffset, transition: .immediate)
        }
    }
    
    public func updateLayout(size: CGSize, topOffset: CGFloat, transition: ContainedViewLayoutTransition) -> CGRect {
        self.validLayout = (size, topOffset)
        
        let fieldAlpha: CGFloat
        switch self.fieldType {
            case .digits6, .digits4:
                fieldAlpha = 0.0
            case .alphanumeric:
                fieldAlpha = 1.0
        }
        
        transition.updateAlpha(node: self.textFieldNode, alpha: fieldAlpha)
        transition.updateAlpha(node: self.borderNode, alpha: fieldAlpha)
        
        let origin = CGPoint(x: floor((size.width - dotDiameter * 6 - dotSpacing * 5) / 2.0), y: topOffset)
        for i in 0 ..< self.dotNodes.count {
            let node = self.dotNodes[i]
            let dotAlpha: CGFloat
            switch self.fieldType {
                case .digits6:
                    dotAlpha = 1.0
                case .digits4:
                    dotAlpha = (i > 0 && i < self.dotNodes.count - 1) ? 1.0 : 0.0
                case .alphanumeric:
                    dotAlpha = 0.0
            }
            transition.updateAlpha(node: node, alpha: dotAlpha)
            
            let dotFrame = CGRect(x: origin.x + CGFloat(i) * (dotDiameter + dotSpacing), y: origin.y, width: dotDiameter, height: dotDiameter)
            transition.updateFrame(node: node, frame: dotFrame)
        }
        
        var inset: CGFloat = 50.0
        if !self.useCustomNumpad || self.fieldBackgroundColor != nil {
            inset = 16.0
        }
        let height: CGFloat = self.fieldType == .alphanumeric && self.fieldBackgroundColor != nil ? 52.0 : fieldHeight
        let fieldFrame = CGRect(x: inset, y: origin.y, width: size.width - inset * 2.0, height: height)
        transition.updateFrame(node: self.borderNode, frame: fieldFrame)
        transition.updateFrame(node: self.textFieldNode, frame: fieldFrame.insetBy(dx: self.fieldBackgroundColor != nil ? 16.0 : 13.0, dy: 0.0))
        
        if let fieldBackgroundColor = self.fieldBackgroundColor {
            self.borderNode.image = generateStretchableFilledCircleImage(diameter: 52.0, color: fieldBackgroundColor)
        } else {
            self.borderNode.image = generateFieldBackgroundImage(backgroundImage: self.background?.foregroundImage, backgroundSize: self.background?.size, frame: fieldFrame)
        }
        
        return fieldFrame
    }
    
    func cancelPendingCompletion() {
        self.inputGeneration += 1
    }

    private func scheduleCompletion(_ text: String) {
        let generation = self.inputGeneration
        Queue.mainQueue().after(0.2) { [weak self] in
            guard let self, self.isInputEnabled, self.inputGeneration == generation, self.text == text else { return }
            self.cancelPendingCompletion()
            self.complete?(text)
        }
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard self.isInputEnabled else { return false }
        let currentText = textField.text ?? ""
        let text = (currentText as NSString).replacingCharacters(in: range, with: string)
        if let maxLength = self.fieldType.maxLength, text.count > maxLength {
            return false
        }
        if let allowedCharacters = self.fieldType.allowedCharacters, let _ = text.rangeOfCharacter(from: allowedCharacters.inverted) {
            return false
        }
        self.cancelPendingCompletion()
        self.updateDots(count: text.count, animated: text.count < currentText.count)
        
        if string == "\n" {
            self.scheduleCompletion(currentText)
            return false
        }
        
        if let maxLength = self.fieldType.maxLength, text.count == maxLength {
            self.scheduleCompletion(text)
        }
        return true
    }
}
