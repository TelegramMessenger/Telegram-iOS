import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private func generateBackground() -> UIImage? {
    let diameter: CGFloat = 8.0
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(0xededed).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        }, opaque: true)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private let searchBarBackground = generateBackground()

private class SearchBarTextField: UITextField {
    private let placeholderLabel: UILabel
    private var placeholderLabelConstrainedSize: CGSize?
    private var placeholderLabelSize: CGSize?
    
    override init(frame: CGRect) {
        self.placeholderLabel = UILabel()
        
        super.init(frame: frame)
        
        self.addSubview(self.placeholderLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 4.0, dy: 4.0)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let constrainedSize = self.textRect(forBounds: self.bounds).size
        if self.placeholderLabelConstrainedSize != constrainedSize {
            self.placeholderLabelConstrainedSize = constrainedSize
            self.placeholderLabelSize = self.placeholderLabel.sizeThatFits(constrainedSize)
        }
        
        if let placeholderLabelSize = self.placeholderLabelSize {
            self.placeholderLabel.frame = CGRect(origin: self.textRect(forBounds: self.bounds).origin, size: placeholderLabelSize)
        }
    }
}

class SearchBarNode: ASDisplayNode, UITextFieldDelegate {
    var cancel: (() -> Void)?
    var textUpdated: ((String) -> Void)?
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textBackgroundNode: ASImageNode
    private let textField: SearchBarTextField
    private let cancelButton: ASButtonNode
    
    var placeholderString: NSAttributedString? {
        get {
            return self.textField.placeholderLabel.attributedText
        } set(value) {
            self.textField.placeholderLabel.attributedText = value
        }
    }
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = UIColor.white
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        
        self.textBackgroundNode = ASImageNode()
        self.textBackgroundNode.isLayerBacked = false
        self.textBackgroundNode.displaysAsynchronously = false
        self.textBackgroundNode.displayWithoutProcessing = true
        self.textBackgroundNode.image = searchBarBackground
        
        self.textField = SearchBarTextField()
        self.textField.font = Font.regular(15.0)
        self.textField.returnKeyType = .done
        
        self.cancelButton = ASButtonNode()
        self.cancelButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.cancelButton.setAttributedTitle(NSAttributedString(string: "Cancel", font: Font.regular(17.0), textColor: UIColor(0x1195f2)), for: [])
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        self.addSubnode(self.textBackgroundNode)
        self.view.addSubview(self.textField)
        self.addSubnode(self.cancelButton)
        
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
    }
    
    override func layout() {
        self.backgroundNode.frame = self.bounds
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.bounds.size.height), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: 100.0, height: CGFloat.infinity))
        self.cancelButton.frame = CGRect(origin: CGPoint(x: self.bounds.size.width - 8.0 - cancelButtonSize.width, y: 20.0 + 10.0), size: cancelButtonSize)
        
        self.textBackgroundNode.frame = CGRect(origin: CGPoint(x: 8.0, y: 20.0 + 8.0), size: CGSize(width: self.bounds.size.width - 16.0 - cancelButtonSize.width - 10.0, height: 28.0))
        
        self.textField.frame = self.textBackgroundNode.frame
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let cancel = self.cancel {
                cancel()
            }
        }
    }
    
    func activate() {
        self.textField.becomeFirstResponder()
    }
    
    func animateIn(from node: SearchBarPlaceholderNode, duration: Double, timingFunction: String) {
        let initialTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, initialTextBackgroundFrame.maxY + 8.0)))
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let initialSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, initialTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.separatorNode.layer.animateFrame(from: initialSeparatorFrame, to: self.separatorNode.frame, duration: duration, timingFunction: timingFunction)
        
        self.textBackgroundNode.layer.animateFrame(from: initialTextBackgroundFrame, to: self.textBackgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let textFieldFrame = self.textField.frame
        let initialLabelNodeFrame = CGRect(origin: node.labelNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x - 4.0, dy: initialTextBackgroundFrame.origin.y - 6.0).origin, size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: initialLabelNodeFrame, to: self.textField.frame, duration: duration, timingFunction: timingFunction)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: initialTextBackgroundFrame.minY + 2.0 + cancelButtonFrame.size.height / 2.0), to: self.cancelButton.layer.position, duration: duration, timingFunction: timingFunction)
        node.isHidden = true
    }
    
    func deactivate() {
        self.textField.resignFirstResponder()
        self.textField.text = nil
        self.textField.placeholderLabel.isHidden = false
    }
    
    func animateOut(to node: SearchBarPlaceholderNode, duration: Double, timingFunction: String, completion: () -> Void) {
        node.isHidden = false
        completion()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.range(of: "\n") != nil {
            return false
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textField.resignFirstResponder()
        return false
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.textField.placeholderLabel.isHidden = !(textField.text?.isEmpty ?? true)
        if let textUpdated = self.textUpdated {
            textUpdated(textField.text ?? "")
        }
    }
    
    @objc func cancelPressed() {
        if let cancel = self.cancel {
            cancel()
        }
    }
}
