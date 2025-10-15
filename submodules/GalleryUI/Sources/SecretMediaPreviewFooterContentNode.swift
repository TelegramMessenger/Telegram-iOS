import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let textFont = Font.regular(16.0)

final class SecretMediaPreviewFooterContentNode: GalleryFooterContentNode {
    private var currentText: String?
    private let textNode: ImmediateTextNode
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func setText(_ text: String) {
        if self.currentText != text {
            self.currentText = text
            
            self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: .white)
            
            self.requestLayout?(.immediate)
        }
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let width = size.width
        let panelHeight: CGFloat = 44.0 + bottomInset
        
        let sideInset: CGFloat = leftInset + 8.0
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: floor((44.0 - textSize.height) / 2.0)), size: textSize))
        
        return panelHeight
    }
}

