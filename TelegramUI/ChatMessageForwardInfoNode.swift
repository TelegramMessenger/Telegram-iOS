import Foundation
import AsyncDisplayKit
import Display
import Postbox

private let prefixFont = Font.regular(13.0)
private let peerFont = Font.medium(13.0)

class ChatMessageForwardInfoNode: ASTransformLayerNode {
    private var textNode: TextNode?
    
    override init() {
        super.init()
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageForwardInfoNode?) -> (_ incoming: Bool, _ peer: Peer, _ authorPeer: Peer?, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageForwardInfoNode) {
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        
        return { incoming, peer, authorPeer, constrainedSize in
            let prefix: NSString = "Forwarded Message\nFrom: "
            let peerString: String
            if let authorPeer = authorPeer {
                peerString = "\(peer.displayTitle) (\(authorPeer.displayTitle))"
            } else {
                peerString = peer.displayTitle
            }
            let completeString: NSString = "\(prefix)\(peerString)" as NSString
            let color = incoming ? UIColor(0x007bff) : UIColor(0x00a516)
            let string = NSMutableAttributedString(string: completeString as String, attributes: [NSForegroundColorAttributeName: color, NSFontAttributeName: prefixFont])
            string.addAttributes([NSFontAttributeName: peerFont], range: NSMakeRange(prefix.length, completeString.length - prefix.length))
            let (textLayout, textApply) = textNodeLayout(string, nil, 2, .end, constrainedSize, .natural, nil)
            
            return (textLayout.size, {
                let node: ChatMessageForwardInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageForwardInfoNode()
                }
                
                let textNode = textApply()
                if node.textNode == nil {
                    textNode.isLayerBacked = true
                    node.textNode = textNode
                    node.addSubnode(textNode)
                }
                textNode.frame = CGRect(origin: CGPoint(), size: textLayout.size)
                
                return node
            })
        }
    }
}
