import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display
import TelegramUIPreferences

final class PeerInfoHeaderMultiLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, ASEditableTextNodeDelegate {
    private let backgroundNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let textNodeContainer: ASDisplayNode
    private let measureTextNode: ImmediateTextNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let requestUpdateHeight: () -> Void
    
    private var fontSize: PresentationFontSize?
    private var theme: PresentationTheme?
    private var currentParams: (width: CGFloat, safeInset: CGFloat)?
    private var currentMeasuredHeight: CGFloat?
    
    var text: String {
        return self.textNode.attributedText?.string ?? ""
    }
    
    init(requestUpdateHeight: @escaping () -> Void) {
        self.requestUpdateHeight = requestUpdateHeight
        
        self.backgroundNode = ASDisplayNode()
        
        self.textNode = EditableTextNode()
        self.textNode.clipsToBounds = false
        self.textNode.textView.clipsToBounds = false
        self.textNode.textContainerInset = UIEdgeInsets()
        
        self.textNodeContainer = ASDisplayNode()
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.maximumNumberOfLines = 0
        self.measureTextNode.isUserInteractionEnabled = false
        self.measureTextNode.lineSpacing = 0.1
        self.topSeparator = ASDisplayNode()
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        self.clearButtonNode.isAccessibilityElement = false
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.textNodeContainer.addSubnode(self.textNode)
        self.addSubnode(self.textNodeContainer)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
        self.addSubnode(self.maskNode)
    
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
        
    @objc private func clearButtonPressed() {
        guard let theme = self.theme else {
            return
        }
        let font: UIFont
        if let fontSize = self.fontSize {
            font = Font.regular(fontSize.itemListBaseFontSize)
        } else {
            font = Font.regular(17.0)
        }
        let attributedText = NSAttributedString(string: "", font: font, textColor: theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = attributedText
        self.requestUpdateHeight()
        self.updateClearButtonVisibility()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        self.currentParams = (width, safeInset)
        
        self.fontSize = presentationData.listsFontSize
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            
            let textColor = presentationData.theme.list.itemPrimaryTextColor
            self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: titleFont, NSAttributedString.Key.foregroundColor.rawValue: textColor]
            self.textNode.keyboardAppearance = presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.tintColor = presentationData.theme.list.itemAccentColor
            
            self.textNode.clipsToBounds = true
            self.textNode.delegate = self
            self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
        }
        
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let separatorX = safeInset + (hasPrevious ? 16.0 : 0.0)
        self.topSeparator.frame = CGRect(origin: CGPoint(x: separatorX, y: 0.0), size: CGSize(width: width - separatorX - safeInset, height: UIScreenPixel))
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: titleFont, textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.attributedPlaceholderText == nil || !self.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
            self.textNode.attributedPlaceholderText = attributedPlaceholderText
        }
        
        if let updateText = updateText {
            let attributedText = NSAttributedString(string: updateText, font: titleFont, textColor: presentationData.theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
        }
        
        var measureText = self.textNode.attributedText?.string ?? ""
        if measureText.hasSuffix("\n") || measureText.isEmpty {
           measureText += "|"
        }
        let attributedMeasureText = NSAttributedString(string: measureText, font: titleFont, textColor: .gray)
        self.measureTextNode.attributedText = attributedMeasureText
        let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
        self.measureTextNode.frame = CGRect(origin: CGPoint(), size: measureTextSize)
        self.currentMeasuredHeight = measureTextSize.height
        
        let height = measureTextSize.height + 22.0
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        let textNodeFrame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: 10.0), size: CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: max(height, 1000.0)))
        self.textNodeContainer.frame = textNodeFrame
        self.textNode.frame = CGRect(origin: CGPoint(), size: textNodeFrame.size)
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: max(1.0, width - safeInset * 2.0), height: height))
        
        let hasCorners = safeInset > 0.0 && (!hasPrevious || !hasNext)
        let hasTopCorners = hasCorners && !hasPrevious
        let hasBottomCorners = hasCorners && !hasNext
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: width - safeInset - safeInset, height: height))
        
        return height
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.isFirstResponder() || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let theme = self.theme else {
            return true
        }
        let updatedText = (editableTextNode.textView.text as NSString).replacingCharacters(in: range, with: text)
        if updatedText.count > 255 {
            let attributedText = NSAttributedString(string: String(updatedText[updatedText.startIndex..<updatedText.index(updatedText.startIndex, offsetBy: 255)]), font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
            self.requestUpdateHeight()
            
            return false
        } else {
            return true
        }
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let (width, safeInset) = self.currentParams {
            var measureText = self.textNode.attributedText?.string ?? ""
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            self.measureTextNode.attributedText = attributedMeasureText
            let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
            if let currentMeasuredHeight = self.currentMeasuredHeight, abs(measureTextSize.height - currentMeasuredHeight) > 0.1 {
                self.requestUpdateHeight()
            }
        }
    }
    
    func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        let text: String? = UIPasteboard.general.string
        if let _ = text {
            return true
        } else {
            return false
        }
    }
}
