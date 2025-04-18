import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display

final class PeerInfoHeaderSingleLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let textNode: TextFieldNode
    private let measureTextNode: ImmediateTextNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var theme: PresentationTheme?
    
    var text: String {
        return self.textNode.textField.text ?? ""
    }
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        
        self.textNode = TextFieldNode()
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.maximumNumberOfLines = 0
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        self.clearButtonNode.isAccessibilityElement = false
        
        self.topSeparator = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
        self.addSubnode(self.maskNode)
        
        self.textNode.textField.delegate = self
        
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
        self.textNode.textField.text = ""
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.textField.isFirstResponder || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        self.textNode.textField.font = titleFont
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            
            self.textNode.textField.textColor = presentationData.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.textField.tintColor = presentationData.theme.list.itemAccentColor
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
        }
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: titleFont, textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.textField.attributedPlaceholder == nil || !self.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
            self.textNode.textField.attributedPlaceholder = attributedPlaceholderText
            self.textNode.textField.accessibilityHint = attributedPlaceholderText.string
        }
        
        if let updateText = updateText {
            self.textNode.textField.text = updateText
        }
        
        if !hasPrevious {
            self.topSeparator.isHidden = true
        }
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        let separatorX = safeInset + (hasPrevious ? 16.0 : 0.0)
        self.topSeparator.frame = CGRect(origin: CGPoint(x: separatorX, y: 0.0), size: CGSize(width: width - separatorX - safeInset, height: UIScreenPixel))
        
        let measureText = "|"
        let attributedMeasureText = NSAttributedString(string: measureText, font: titleFont, textColor: .black)
        self.measureTextNode.attributedText = attributedMeasureText
        let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
        
        let height = measureTextSize.height + 22.0
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: max(1.0, width - safeInset * 2.0), height: height))
        self.textNode.frame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: floor((height - 40.0) / 2.0)), size: CGSize(width: max(1.0, width - safeInset * 2.0 - 16.0 * 2.0 - 38.0), height: 40.0))
        
        let hasCorners = safeInset > 0.0 && (!hasPrevious || !hasNext)
        let hasTopCorners = hasCorners && !hasPrevious
        let hasBottomCorners = hasCorners && !hasNext
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: width - safeInset - safeInset, height: height))
        
        self.textNode.isUserInteractionEnabled = isEnabled
        self.textNode.alpha = isEnabled ? 1.0 : 0.6
        
        return height
    }
}
