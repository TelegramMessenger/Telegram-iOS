import Foundation
import UIKit
import Display

class ResizeableTextInputViewImpl: UITextView {
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(contentOffset, animated: false)
    }
}

class ResizeableTextInputView: UIView, UITextViewDelegate {
    let textView: ResizeableTextInputViewImpl
    let shadowTextView: ResizeableTextInputViewImpl
    let placeholderLabel: UILabel
    var updateHeight: () -> Void = { }
    var maxHeightForLines: CGFloat
    var heightForSingleLine: CGFloat
    let insets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 4.0, right: 0.0)
    
    var placeholder: String {
        get {
            return self.placeholderLabel.text ?? ""
        } set(value) {
            self.placeholderLabel.text = value
            self.placeholderLabel.sizeToFit()
            let placeholderSize = self.placeholderLabel.bounds.size
            self.placeholderLabel.frame = CGRect(x: 2.0, y: self.insets.top, width: placeholderSize.width, height: placeholderSize.height)
        }
    }
    
    init() {
        self.textView = ResizeableTextInputViewImpl()
        self.textView.layoutManager.allowsNonContiguousLayout = true
        self.textView.textContainerInset = UIEdgeInsets(top: 0.0, left: self.insets.left, bottom: 0.0, right: self.insets.right)
        self.textView.backgroundColor = UIColor.clear
        self.textView.textColor = UIColor.black
        self.textView.isOpaque = false
        self.textView.font = Font.regular(16.0)
        
        self.shadowTextView = ResizeableTextInputViewImpl()
        self.shadowTextView.font = self.textView.font
        self.shadowTextView.textContainerInset = self.textView.textContainerInset
        self.shadowTextView.layoutManager.allowsNonContiguousLayout = true
        self.shadowTextView.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: CGFloat.greatestFiniteMagnitude)
        
        self.shadowTextView.text = "A"
        self.shadowTextView.layoutManager.ensureLayout(for: shadowTextView.textContainer)
        let singleLineHeight = ceil(shadowTextView.layoutManager.usedRect(for: shadowTextView.textContainer).size.height)
        self.heightForSingleLine = singleLineHeight + 2.0 + self.insets.top + self.insets.bottom
        
        self.shadowTextView.text = "\n\n\n"
        self.shadowTextView.layoutManager.ensureLayout(for: shadowTextView.textContainer)
        let maxHeight = ceil(shadowTextView.layoutManager.usedRect(for: shadowTextView.textContainer).size.height)
        self.maxHeightForLines = maxHeight + 2.0 + self.insets.top + self.insets.bottom
        
        self.placeholderLabel = UILabel()
        
        super.init(frame: CGRect())
        
        self.clipsToBounds = true
        
        self.textView.delegate = self
        self.addSubview(textView)
        
        self.placeholderLabel.font = self.textView.font
        self.placeholderLabel.textColor = UIColor(0xbebec0)
        self.addSubview(self.placeholderLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func maxHeight() -> CGFloat {
        return self.maxHeightForLines ?? 0.0
    }
    
    func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
        self.shadowTextView.frame = CGRect(x: 0.0, y: 0.0, width: constrainedSize.width + 4.0, height: CGFloat.greatestFiniteMagnitude)
        self.shadowTextView.text = "\n"
        //shadowTextView.layoutManager.ensureLayoutForTextContainer(shadowTextView.textContainer)
        self.shadowTextView.text = textView.text
        
        shadowTextView.layoutManager.glyphRange(for: shadowTextView.textContainer)
        let height = ceil(shadowTextView.layoutManager.usedRect(for: shadowTextView.textContainer).size.height)
        
        return CGSize(width: constrainedSize.width, height: min(height + 2.0 + self.insets.top + self.insets.bottom, self.maxHeight()))
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = textView.text.startIndex != textView.text.endIndex
        self.updateHeight()
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            super.frame = value
            
            let heightFix: CGFloat = 25.0
            self.textView.frame = CGRect(x: -4.0, y: -0.5, width: value.size.width + 4.0, height: value.size.height + heightFix - self.insets.bottom)
            let distance = -(self.maxHeight() - self.textView.frame.size.height)
            self.clipsToBounds = distance > 0.0
            self.textView.contentInset = UIEdgeInsets(top: 2.0 + self.insets.top, left: 0.0, bottom: max(0.0, distance) + self.insets.bottom, right: 0.0)
            self.textView.scrollIndicatorInsets = UIEdgeInsets(top: 2.0 + self.insets.top, left: 0.0, bottom: max(0.0, distance) + self.insets.bottom, right: -2.0)
            
            let placeholderSize = self.placeholderLabel.bounds.size
            self.placeholderLabel.frame = CGRect(x: 1.0, y: self.insets.top + 2.0, width: placeholderSize.width, height: placeholderSize.height)
        }
    }
}
