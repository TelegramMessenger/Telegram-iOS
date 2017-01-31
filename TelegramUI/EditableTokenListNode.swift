import Foundation
import AsyncDisplayKit
import Display

struct EditableTokenListToken {
    let id: AnyHashable
    let title: String
}

private final class TokenNode: ASDisplayNode {
    let token: EditableTokenListToken
    let titleNode: ASTextNode
    
    init(token: EditableTokenListToken) {
        self.token = token
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.titleNode.attributedText = NSAttributedString(string: token.title + ",", font: Font.regular(15.0), textColor: .black)
        self.addSubnode(self.titleNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(CGSize(width: constrainedSize.width - 8.0, height: constrainedSize.height))
        return CGSize(width: titleSize.width + 8.0, height: 26.0)
    }
    
    override func layout() {
        let titleSize = self.titleNode.calculatedSize
        if titleSize.width.isZero {
            return
        }
        self.titleNode.frame = CGRect(origin: CGPoint(x: 4.0, y: floor((self.bounds.size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}

final class EditableTokenListNode: ASDisplayNode {
    private let placeholderNode: ASTextNode
    private var tokenNodes: [TokenNode] = []
    private let separatorNode: ASDisplayNode
    
    override init() {
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isLayerBacked = true
        self.placeholderNode.maximumNumberOfLines = 1
        self.placeholderNode.attributedText = NSAttributedString(string: "Whom would you like to message?", font: Font.regular(15.0), textColor: UIColor(0x8e8e92))
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = UIColor(0xc7c6cb)
        
        super.init()
        
        self.backgroundColor = UIColor(0xf7f7f7)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.separatorNode)
        self.clipsToBounds = true
    }
    
    func updateLayout(tokens: [EditableTokenListToken], width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let validTokens = Set<AnyHashable>(tokens.map { $0.id })
        
        for i in (0 ..< self.tokenNodes.count).reversed() {
            let tokenNode = tokenNodes[i]
            if !validTokens.contains(tokenNode.token.id) {
                self.tokenNodes.remove(at: i)
                transition.updateAlpha(node: tokenNode, alpha: 0.0, completion: { [weak tokenNode] _ in
                    tokenNode?.removeFromSupernode()
                })
            }
        }
        
        let sideInset: CGFloat = 4.0
        let verticalInset: CGFloat = 7.0
        
        let placeholderSize = self.placeholderNode.measure(CGSize(width: max(1.0, width - sideInset - sideInset), height: CGFloat.greatestFiniteMagnitude))
        self.placeholderNode.frame = CGRect(origin: CGPoint(x: sideInset + 4.0, y: verticalInset + floor((26.0 - placeholderSize.height) / 2.0)), size: placeholderSize)
        
        transition.updateAlpha(node: self.placeholderNode, alpha: tokens.isEmpty ? 1.0 : 0.0)
        
        var currentOffset = CGPoint(x: sideInset, y: verticalInset)
        for token in tokens {
            var currentNode: TokenNode?
            for node in self.tokenNodes {
                if node.token.id == token.id {
                    currentNode = node
                    break
                }
            }
            let tokenNode: TokenNode
            var animateIn = false
            if let currentNode = currentNode {
                tokenNode = currentNode
            } else {
                tokenNode = TokenNode(token: token)
                self.tokenNodes.append(tokenNode)
                self.addSubnode(tokenNode)
                animateIn = true
            }
            
            let tokenSize = tokenNode.measure(CGSize(width: max(1.0, width - sideInset - sideInset), height: CGFloat.greatestFiniteMagnitude))
            if tokenSize.width + currentOffset.x >= width - sideInset {
                currentOffset.x = sideInset
                currentOffset.y += tokenSize.height
            }
            let tokenFrame = CGRect(origin: CGPoint(x: currentOffset.x, y: currentOffset.y), size: tokenSize)
            currentOffset.x += tokenSize.width
            
            if animateIn {
                tokenNode.frame = tokenFrame
                tokenNode.alpha = 0.0
                transition.updateAlpha(node: tokenNode, alpha: 1.0)
            } else {
                transition.updateFrame(node: tokenNode, frame: tokenFrame)
            }
        }
        
        let nodeHeight = currentOffset.y + 28.0 + verticalInset
        
        let separatorHeight = UIScreenPixel
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: nodeHeight - separatorHeight), size: CGSize(width: width, height: separatorHeight)))
        
        return nodeHeight
    }
}
