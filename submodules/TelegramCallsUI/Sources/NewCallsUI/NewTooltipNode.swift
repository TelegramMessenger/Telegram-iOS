import Foundation
import UIKit
import Display
import AsyncDisplayKit

enum NewToastContent {
    case micro
    case lowConnections

    var content: String {
        switch self {
        case .micro:
            return "Your microphone is turned off"

        case .lowConnections:
            return "Weak network signal"
        }
    }
}

final class NewCallControllerToastNode: ASDisplayNode {
    
    private var isHeddenNode = true
    private let toastContent: NewToastContent
    private let textNode = ImmediateTextNode()
    
    init(toastContent: NewToastContent, colorNode: UIColor) {
        self.toastContent = toastContent
        super.init()
        isHidden = true
        backgroundColor = colorNode
        
        addSubnode(textNode)
    }
    
    func updateLayout(frame: CGRect) {
        cornerRadius = frame.size.height / 2
        
        textNode.attributedText = NSAttributedString(string: toastContent.content,
                                                     font: UIFont.systemFont(ofSize: 16),
                                                     textColor: .white)
        let textNodeHeight = textNode.attributedText?.height(withConstrainedWidth: frame.width) ?? 0
        let textNodeWidth = textNode.attributedText?.width(withConstrainedHeight: frame.height) ?? 0
        
        textNode.textAlignment = .center
        let textNodeSize = textNode.updateLayout(CGSize(width: textNodeWidth, height: textNodeHeight))
        textNode.frame = CGRect(x: (frame.width - textNodeWidth) / 2,
                                y: (frame.height - textNodeHeight) / 2,
                                width: textNodeSize.width,
                                height: textNodeSize.height)
    }
    
    func updateState() {
        isHeddenNode = !isHeddenNode
        if isHeddenNode {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.layer.animateScale(from: 1, to: 0.4, duration: 0.25) { [weak self] _ in
                self?.isHidden = true
            }
        } else {
            isHidden = false
            self.layer.animateAlpha(from: 0.5, to: 1.0, duration: 0.25, removeOnCompletion: false)
            self.layer.animateScale(from: 0.4, to: 1.0, duration: 0.25)
        }
    }
}

private extension NSAttributedString {
    func height(withConstrainedWidth width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
    
        return ceil(boundingBox.height)
    }

    func width(withConstrainedHeight height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
    
        return ceil(boundingBox.width)
    }
}
