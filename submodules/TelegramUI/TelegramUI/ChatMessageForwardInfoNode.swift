import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import LocalizedPeerData

enum ChatMessageForwardInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageForwardInfoNode: ASDisplayNode {
    private var textNode: TextNode?
    private var credibilityIconNode: ASImageNode?
    
    override init() {
        super.init()
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageForwardInfoNode?) -> (_ presentationData: ChatPresentationData, _ strings: PresentationStrings, _ type: ChatMessageForwardInfoType, _ peer: Peer?, _ authorName: String?, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageForwardInfoNode) {
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        
        return { presentationData, strings, type, peer, authorName, constrainedSize in
            let fontSize = floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)
            let prefixFont = Font.regular(fontSize)
            let peerFont = Font.medium(fontSize)
            
            let peerString: String
            if let peer = peer {
                if let authorName = authorName {
                    peerString = "\(peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)) (\(authorName))"
                } else {
                    peerString = peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else if let authorName = authorName {
                peerString = authorName
            } else {
                peerString = ""
            }
            
            let titleColor: UIColor
            let completeSourceString: (String, [(Int, NSRange)])
            
            switch type {
                case let .bubble(incoming):
                    titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.accentTextColor : presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    completeSourceString = strings.Message_ForwardedMessage(peerString)
                case .standalone:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    titleColor = serviceColor.primaryText
                    completeSourceString = strings.Message_ForwardedMessageShort(peerString)
            }
            
            var currentCredibilityIconImage: UIImage?
            var highlight = true
            if let peer = peer {
                if let channel = peer as? TelegramChannel, channel.username == nil {
                    if case .member = channel.participationStatus {
                    } else {
                        highlight = false
                    }
                }
                
                if peer.isScam {
                    switch type {
                        case let .bubble(incoming):
                            currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, type: incoming ? .regular : .outgoing)
                        case .standalone:
                            currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, type: .service)
                    }
                } else {
                    currentCredibilityIconImage = nil
                }
            } else {
                highlight = false
            }
            
            let completeString: NSString = completeSourceString.0 as NSString
            let string = NSMutableAttributedString(string: completeString as String, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: prefixFont])
            if highlight, let range = completeSourceString.1.first?.1 {
                string.addAttributes([NSAttributedString.Key.font: peerFont], range: range)
            }
            
            var credibilityIconWidth: CGFloat = 0.0
            if let icon = currentCredibilityIconImage {
                credibilityIconWidth += icon.size.width + 4.0
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - credibilityIconWidth, height: constrainedSize.height), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (CGSize(width: textLayout.size.width + credibilityIconWidth, height: textLayout.size.height), {
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
                
                if let credibilityIconImage = currentCredibilityIconImage {
                    let credibilityIconNode: ASImageNode
                    if let node = node.credibilityIconNode {
                        credibilityIconNode = node
                    } else {
                        credibilityIconNode = ASImageNode()
                        node.credibilityIconNode = credibilityIconNode
                        node.addSubnode(credibilityIconNode)
                    }
                    credibilityIconNode.frame = CGRect(origin: CGPoint(x: textLayout.size.width + 4.0, y: 16.0), size: credibilityIconImage.size)
                    credibilityIconNode.image = credibilityIconImage
                } else {
                    node.credibilityIconNode?.removeFromSupernode()
                    node.credibilityIconNode = nil
                }
                
                return node
            })
        }
    }
}
