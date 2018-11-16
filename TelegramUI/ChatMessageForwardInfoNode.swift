import Foundation
import AsyncDisplayKit
import Display
import Postbox

private let prefixFont = Font.regular(13.0)
private let peerFont = Font.medium(13.0)

enum ChatMessageForwardInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageForwardInfoNode: ASDisplayNode {
    private var textNode: TextNode?
    
    override init() {
        super.init()
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageForwardInfoNode?) -> (_ theme: PresentationTheme, _ strings: PresentationStrings, _ type: ChatMessageForwardInfoType, _ peer: Peer, _ authorName: String?, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageForwardInfoNode) {
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        
        return { theme, strings, type, peer, authorName, constrainedSize in
            let peerString: String
            if let authorName = authorName {
                peerString = "\(peer.displayTitle(strings: strings)) (\(authorName))"
            } else {
                peerString = peer.displayTitle(strings: strings)
            }
            
            let titleColor: UIColor
            let completeSourceString: (String, [(Int, NSRange)])
            
            switch type {
                case let .bubble(incoming):
                    titleColor = incoming ? theme.chat.bubble.incomingAccentTextColor : theme.chat.bubble.outgoingAccentTextColor
                    completeSourceString = strings.Message_ForwardedMessage(peerString)
                case .standalone:
                    titleColor = theme.chat.serviceMessage.serviceMessagePrimaryTextColor
                    completeSourceString = strings.Message_ForwardedMessageShort(peerString)
            }
            
            let completeString: NSString = completeSourceString.0 as NSString
            let string = NSMutableAttributedString(string: completeString as String, attributes: [NSAttributedStringKey.foregroundColor: titleColor, NSAttributedStringKey.font: prefixFont])
            if let range = completeSourceString.1.first?.1 {
                string.addAttributes([NSAttributedStringKey.font: peerFont], range: range)
            }
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (textLayout.size, {
                let node: ChatMessageForwardInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageForwardInfoNode()
                }
                
                let textNode = textApply()
                if node.textNode == nil {
                    textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.addSubnode(textNode)
                }
                textNode.frame = CGRect(origin: CGPoint(), size: textLayout.size)
                
                return node
            })
        }
    }
}
