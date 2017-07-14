import Foundation
import AsyncDisplayKit

public enum TextAlertActionType {
    case genericAction
    case defaultAction
}

public struct TextAlertAction {
    public let type: TextAlertActionType
    public let title: String
    public let action: () -> Void
    
    public init(type: TextAlertActionType, title: String, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.action = action
    }
}

private final class TextAlertContentActionNode: HighlightableButtonNode {
    private let backgroundNode: ASDisplayNode
    
    let action: TextAlertAction
    
    init(action: TextAlertAction) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = UIColor(rgb: 0xe0e5e6)
        self.backgroundNode.alpha = 0.0
        
        self.action = action
        
        super.init()
        
        self.setTitle(action.title, with: action.type == .defaultAction ? Font.medium(17.0) : Font.regular(17.0), with: UIColor(rgb: 0x007ee5), for: [])
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 1.0
                } else if !strongSelf.backgroundNode.alpha.isZero {
                    strongSelf.backgroundNode.alpha = 0.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

final class TextAlertContentNode: AlertContentNode {
    private let titleNode: ASTextNode?
    private let textNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    init(title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction]) {
        if let title = title {
            let titleNode = ASTextNode()
            titleNode.attributedText = title
            titleNode.displaysAsynchronously = false
            titleNode.isLayerBacked = true
            titleNode.maximumNumberOfLines = 1
            titleNode.truncationMode = .byTruncatingTail
            self.titleNode = titleNode
        } else {
            self.titleNode = nil
        }
        
        self.textNode = ASTextNode()
        self.textNode.attributedText = text
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = true
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = UIColor(rgb: 0xc9cdd7)
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                separatorNode.backgroundColor = UIColor(rgb: 0xc9cdd7)
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        if let titleNode = self.titleNode {
            self.addSubnode(titleNode)
        }
        self.addSubnode(self.textNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var titleSize: CGSize?
        if let titleNode = self.titleNode {
            titleSize = titleNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        }
        let textSize = self.textNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let actionsHeight: CGFloat = 44.0
        
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionsHeight))
            minActionsWidth += actionTitleSize.width + actionTitleInsets
        }
        
        let resultSize: CGSize
        
        if let titleNode = titleNode, let titleSize = titleSize {
            let contentWidth = max(max(titleSize.width, textSize.width), minActionsWidth)
            
            let spacing: CGFloat = 6.0
            let titleFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - titleSize.width) / 2.0), y: insets.top), size: titleSize)
            transition.updateFrame(node: titleNode, frame: titleFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: titleFrame.maxY + spacing), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom)
        } else {
            let textFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            resultSize = CGSize(width: textSize.width + insets.left + insets.right, height: textSize.height + actionsHeight + insets.top + insets.bottom)
        }
        
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            if nodeIndex == self.actionNodes.count - 1 {
                currentActionWidth = resultSize.width - actionOffset
            } else {
                currentActionWidth = actionWidth
            }
            
            let actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionsHeight))
            
            actionOffset += currentActionWidth
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

public func textAlertController(title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction]) -> AlertController {
    return AlertController(contentNode: TextAlertContentNode(title: title, text: text, actions: actions))
}

public func standardTextAlertController(title: String?, text: String, actions: [TextAlertAction]) -> AlertController {
    var dismissImpl: (() -> Void)?
    let controller = AlertController(contentNode: TextAlertContentNode(title: title != nil ? NSAttributedString(string: title!, font: Font.medium(17.0), textColor: .black, paragraphAlignment: .center) : nil, text: NSAttributedString(string: text, font: title == nil ? Font.semibold(17.0) : Font.regular(13.0), textColor: .black, paragraphAlignment: .center), actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }))
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
