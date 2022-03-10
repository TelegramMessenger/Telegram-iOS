import Foundation
import UIKit
import AsyncDisplayKit
import Display
import PhoneNumberFormat

public final class CodeInputView: ASDisplayNode, UITextFieldDelegate {
    public struct Theme: Equatable {
        public var inactiveBorder: UInt32
        public var activeBorder: UInt32
        public var foreground: UInt32
        public var isDark: Bool
        
        public init(
            inactiveBorder: UInt32,
            activeBorder: UInt32,
            foreground: UInt32,
            isDark: Bool
        ) {
            self.inactiveBorder = inactiveBorder
            self.activeBorder = activeBorder
            self.foreground = foreground
            self.isDark = isDark
        }
    }
    
    private final class ItemView: ASDisplayNode {
        private let backgroundView: UIView
        private let textNode: ImmediateTextNode
        
        private var borderColorValue: UInt32?
        
        private var text: String = ""
        
        override init() {
            self.backgroundView = UIView()
            self.textNode = ImmediateTextNode()
            
            super.init()
            
            self.addSubnode(self.textNode)
            self.view.addSubview(self.backgroundView)
            
            self.clipsToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(borderColor: UInt32, isHighlighted: Bool) {
            if self.borderColorValue != borderColor {
                self.borderColorValue = borderColor
                
                let previousColor = self.backgroundView.layer.borderColor
                self.backgroundView.layer.cornerRadius = 5.0
                self.backgroundView.layer.borderColor = UIColor(argb: borderColor).cgColor
                self.backgroundView.layer.borderWidth = 1.0
                if let previousColor = previousColor {
                    self.backgroundView.layer.animate(from: previousColor, to: UIColor(argb: borderColor).cgColor, keyPath: "borderColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.15)
                }
            }
        }
        
        func update(textColor: UInt32, text: String, size: CGSize, animated: Bool) {
            let previousText = self.text
            self.text = text
            
            if animated && previousText.isEmpty != text.isEmpty {
                if !text.isEmpty {
                    self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    self.textNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: size.height / 2.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, additive: true)
                } else {
                    if let copyView = self.textNode.view.snapshotContentTree() {
                        self.view.insertSubview(copyView, at: 0)
                        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                            copyView?.removeFromSuperview()
                        })
                        copyView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: size.height / 2.0), duration: 0.2, removeOnCompletion: false, additive: true)
                    }
                }
            }
            
            let fontSize: CGFloat = floor(21.0 * size.height / 28.0)
            
            if #available(iOS 13.0, *) {
                self.textNode.attributedText = NSAttributedString(string: text, font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), textColor: UIColor(argb: textColor))
            } else {
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.monospace(fontSize), textColor: UIColor(argb: textColor))
            }
            let textSize = self.textNode.updateLayout(size)
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
            
            self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
    
    private let prefixLabel: ImmediateTextNode
    public let textField: UITextField
    
    private var focusIndex: Int? = 0
    private var itemViews: [ItemView] = []
    
    public var updated: (() -> Void)?
    
    private var theme: Theme?
    private var count: Int?
    
    private var textValue: String = ""
    public var text: String {
        get {
            return self.textValue
        } set(value) {
            self.textValue = value
            self.textField.text = value
        }
    }
    
    override public init() {
        self.prefixLabel = ImmediateTextNode()
        self.textField = UITextField()
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.textField.keyboardType = .numberPad
        }
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            self.textField.textContentType = .oneTimeCode
        }
        self.textField.returnKeyType = .done
        self.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        super.init()
        
        self.addSubnode(self.prefixLabel)
        self.view.addSubview(self.textField)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
    }
    
    required public init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.textField.becomeFirstResponder()
        }
    }
    
    @objc func textFieldChanged(_ textField: UITextField) {
        self.textValue = textField.text ?? ""
        self.updateItemViews(animated: true)
        self.updated?()
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let count = self.count else {
            return false
        }
        var text = textField.text ?? ""
        guard let stringRange = Range(range, in: text) else {
            return false
        }
        text.replaceSubrange(stringRange, with: string)
        
        if !text.allSatisfy({ $0.isNumber && $0.isASCII }) {
            return false
        }
        
        if text.count > count {
            return false
        }
        
        return true
    }
    
    private func currentCaretIndex() -> Int? {
        if let selectedTextRange = self.textField.selectedTextRange {
            let index = self.textField.offset(from: self.textField.beginningOfDocument, to: selectedTextRange.end)
            return index
        } else {
            return nil
        }
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.focusIndex = self.currentCaretIndex()
        self.updateItemViews(animated: true)
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.focusIndex = textField.text?.count ?? 0
        self.updateItemViews(animated: true)
    }
    
    public func textFieldDidChangeSelection(_ textField: UITextField) {
        self.focusIndex = self.currentCaretIndex()
        self.updateItemViews(animated: true)
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }
    
    private func updateItemViews(animated: Bool) {
        guard let theme = self.theme else {
            return
        }
        
        for i in 0 ..< self.itemViews.count {
            let itemView = self.itemViews[i]
            let itemSize = itemView.bounds.size
            
            itemView.update(borderColor: self.focusIndex == i ? theme.activeBorder : theme.inactiveBorder, isHighlighted: self.focusIndex == i)
            let itemText: String
            if i < self.textValue.count {
                itemText = String(self.textValue[self.textValue.index(self.textValue.startIndex, offsetBy: i)])
            } else {
                itemText = ""
            }
            itemView.update(textColor: theme.foreground, text: itemText, size: itemSize, animated: animated)
        }
    }
    
    public func update(theme: Theme, prefix: String, count: Int, width: CGFloat) -> CGSize {
        self.theme = theme
        self.count = count
        
        if theme.isDark {
            self.textField.keyboardAppearance = .dark
        } else {
            self.textField.keyboardAppearance = .light
        }
        
        let height: CGFloat
        if prefix.isEmpty {
            height = 40.0
        } else {
            height = 28.0
        }
        
        if #available(iOS 13.0, *) {
            self.prefixLabel.attributedText = NSAttributedString(string: prefix, font: UIFont.monospacedSystemFont(ofSize: 21.0, weight: .regular), textColor: UIColor(argb: theme.foreground))
        } else {
            self.prefixLabel.attributedText = NSAttributedString(string: prefix, font: Font.monospace(21.0), textColor: UIColor(argb: theme.foreground))
        }
        let prefixSize = self.prefixLabel.updateLayout(CGSize(width: width, height: 100.0))
        let prefixSpacing: CGFloat = prefix.isEmpty ? 0.0 : 8.0
        
        let itemSize = CGSize(width: floor(25.0 * height / 28.0), height: height)
        let itemSpacing: CGFloat = 5.0
        let itemsWidth: CGFloat = itemSize.width * CGFloat(count) + itemSpacing * CGFloat(count - 1)
        
        let contentWidth: CGFloat = prefixSize.width + prefixSpacing + itemsWidth
        let contentOriginX: CGFloat = floor((width - contentWidth) / 2.0)
        
        self.prefixLabel.frame = CGRect(origin: CGPoint(x: contentOriginX, y: floorToScreenPixels((height - prefixSize.height) / 2.0)), size: prefixSize)
        
        for i in 0 ..< count {
            let itemView: ItemView
            if self.itemViews.count > i {
                itemView = self.itemViews[i]
            } else {
                itemView = ItemView()
                self.itemViews.append(itemView)
                self.addSubnode(itemView)
            }
            itemView.update(borderColor: self.focusIndex == i ? theme.activeBorder : theme.inactiveBorder, isHighlighted: self.focusIndex == i)
            let itemText: String
            if i < self.textValue.count {
                itemText = String(self.textValue[self.textValue.index(self.textValue.startIndex, offsetBy: i)])
            } else {
                itemText = ""
            }
            itemView.update(textColor: theme.foreground, text: itemText, size: itemSize, animated: false)
            itemView.frame = CGRect(origin: CGPoint(x: contentOriginX + prefixSize.width + prefixSpacing + CGFloat(i) * (itemSize.width + itemSpacing), y: 0.0), size: itemSize)
        }
        if self.itemViews.count > count {
            for i in count ..< self.itemViews.count {
                self.itemViews[i].removeFromSupernode()
            }
            self.itemViews.removeSubrange(count...)
        }
        
        return CGSize(width: width, height: height)
    }
    
    public override func becomeFirstResponder() -> Bool {
        return self.textField.becomeFirstResponder()
    }
    
    public override func canBecomeFirstResponder() -> Bool {
        return self.textField.canBecomeFirstResponder
    }
    
    public override func resignFirstResponder() -> Bool {
        return self.textField.resignFirstResponder()
    }
    
    public override func canResignFirstResponder() -> Bool {
        return self.textField.canResignFirstResponder
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.view
        } else {
            return nil
        }
    }
}
