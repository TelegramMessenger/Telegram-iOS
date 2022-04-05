import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData

enum ChatMessageForwardInfoType: Equatable {
    case bubble(incoming: Bool)
    case standalone
}

private final class InfoButtonNode: HighlightableButtonNode {
    private let pressed: () -> Void
    let iconNode: ASImageNode
    
    private var theme: ChatPresentationThemeData?
    private var type: ChatMessageForwardInfoType?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.iconNode)
        
        self.addTarget(self, action: #selector(self.pressedEvent), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressedEvent() {
        self.pressed()
    }
    
    func update(size: CGSize, theme: ChatPresentationThemeData, type: ChatMessageForwardInfoType) {
        if self.theme !== theme || self.type != type {
            self.theme = theme
            self.type = type
            let color: UIColor
            switch type {
            case let .bubble(incoming):
                color = incoming ? theme.theme.chat.message.incoming.accentControlColor : theme.theme.chat.message.outgoing.accentControlColor
            case .standalone:
                let serviceColor = serviceMessageColorComponents(theme: theme.theme, wallpaper: theme.wallpaper)
                color = serviceColor.primaryText
            }
            self.iconNode.image = PresentationResourcesChat.chatPsaInfo(theme.theme, color: color.argb)
        }
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
}

class ChatMessageForwardInfoNode: ASDisplayNode {
    private var textNode: TextNode?
    private var credibilityIconNode: ASImageNode?
    private var infoNode: InfoButtonNode?
    
    var openPsa: ((String, ASDisplayNode) -> Void)?
    
    override init() {
        super.init()
    }
    
    func hasAction(at point: CGPoint) -> Bool {
        if let infoNode = self.infoNode, infoNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
    
    func updatePsaButtonDisplay(isVisible: Bool, animated: Bool) {
        if let infoNode = self.infoNode {
            if isVisible != !infoNode.iconNode.alpha.isZero {
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.25, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                transition.updateAlpha(node: infoNode.iconNode, alpha: isVisible ? 1.0 : 0.0)
                transition.updateSublayerTransformScale(node: infoNode, scale: isVisible ? 1.0 : 0.1)
            }
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageForwardInfoNode?) -> (_ presentationData: ChatPresentationData, _ strings: PresentationStrings, _ type: ChatMessageForwardInfoType, _ peer: Peer?, _ authorName: String?, _ psaType: String?, _ constrainedSize: CGSize) -> (CGSize, (CGFloat) -> ChatMessageForwardInfoNode) {
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        
        return { presentationData, strings, type, peer, authorName, psaType, constrainedSize in
            let fontSize = floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)
            let prefixFont = Font.regular(fontSize)
            let peerFont = Font.medium(fontSize)
            
            let peerString: String
            if let peer = peer {
                if let authorName = authorName {
                    peerString = "\(EnginePeer(peer).displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)) (\(authorName))"
                } else {
                    peerString = EnginePeer(peer).displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else if let authorName = authorName {
                peerString = authorName
            } else {
                peerString = ""
            }
            
            var hasPsaInfo = false
            if let _ = psaType {
                hasPsaInfo = true
            }
            
            let titleColor: UIColor
            let completeSourceString: PresentationStrings.FormattedString
            
            switch type {
                case let .bubble(incoming):
                    if let psaType = psaType {
                        titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barPositive : presentationData.theme.theme.chat.message.outgoing.polls.barPositive
                        
                        var customFormat: String?
                        let key = "Message.ForwardedPsa.\(psaType)"
                        if let string = presentationData.strings.primaryComponent.dict[key] {
                            customFormat = string
                        } else if let string = presentationData.strings.secondaryComponent?.dict[key] {
                            customFormat = string
                        }
                        
                        if let customFormat = customFormat {
                            if let range = customFormat.range(of: "%@") {
                                let leftPart = String(customFormat[customFormat.startIndex ..< range.lowerBound])
                                let rightPart = String(customFormat[range.upperBound...])
                                
                                let formattedText = leftPart + peerString + rightPart
                                completeSourceString = PresentationStrings.FormattedString(string: formattedText, ranges: [PresentationStrings.FormattedString.Range(index: 0, range: NSRange(location: leftPart.count, length: peerString.count))])
                            } else {
                                completeSourceString = PresentationStrings.FormattedString(string: customFormat, ranges: [])
                            }
                        } else {
                            completeSourceString = strings.Message_GenericForwardedPsa(peerString)
                        }
                    } else {
                        titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.accentTextColor : presentationData.theme.theme.chat.message.outgoing.accentTextColor
                        completeSourceString = strings.Message_ForwardedMessageShort(peerString)
                    }
                case .standalone:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    titleColor = serviceColor.primaryText
                    
                    if let psaType = psaType {
                        var customFormat: String?
                        let key = "Message.ForwardedPsa.\(psaType)"
                        if let string = presentationData.strings.primaryComponent.dict[key] {
                            customFormat = string
                        } else if let string = presentationData.strings.secondaryComponent?.dict[key] {
                            customFormat = string
                        }
                        
                        if let customFormat = customFormat {
                            if let range = customFormat.range(of: "%@") {
                                let leftPart = String(customFormat[customFormat.startIndex ..< range.lowerBound])
                                let rightPart = String(customFormat[range.upperBound...])
                                
                                let formattedText = leftPart + peerString + rightPart
                                completeSourceString = PresentationStrings.FormattedString(string: formattedText, ranges: [PresentationStrings.FormattedString.Range(index: 0, range: NSRange(location: leftPart.count, length: peerString.count))])
                            } else {
                                completeSourceString = PresentationStrings.FormattedString(string: customFormat, ranges: [])
                            }
                        } else {
                            completeSourceString = strings.Message_GenericForwardedPsa(peerString)
                        }
                    } else {
                        completeSourceString = strings.Message_ForwardedMessageShort(peerString)
                    }
            }
            
            var currentCredibilityIconImage: UIImage?
            var highlight = true
            if let peer = peer {
                if let channel = peer as? TelegramChannel, channel.username == nil {
                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                    } else if case .member = channel.participationStatus {
                    } else {
                        highlight = false
                    }
                }
                
                if peer.isFake {
                    switch type {
                        case let .bubble(incoming):
                            currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(presentationData.theme.theme, strings: presentationData.strings, type: incoming ? .regular : .outgoing)
                        case .standalone:
                            currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(presentationData.theme.theme, strings: presentationData.strings, type: .service)
                    }
                } else if peer.isScam {
                    switch type {
                        case let .bubble(incoming):
                            currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, strings: presentationData.strings, type: incoming ? .regular : .outgoing)
                        case .standalone:
                            currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, strings: presentationData.strings, type: .service)
                    }
                } else {
                    currentCredibilityIconImage = nil
                }
            } else {
                highlight = false
            }
            
            let completeString: NSString = completeSourceString.string as NSString
            let string = NSMutableAttributedString(string: completeString as String, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: prefixFont])
            if highlight, let range = completeSourceString.ranges.first?.range {
                string.addAttributes([NSAttributedString.Key.font: peerFont], range: range)
            }
            
            var credibilityIconWidth: CGFloat = 0.0
            if let icon = currentCredibilityIconImage {
                credibilityIconWidth += icon.size.width + 4.0
            }
            
            var infoWidth: CGFloat = 0.0
            if hasPsaInfo {
                infoWidth += 32.0
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - credibilityIconWidth - infoWidth, height: constrainedSize.height), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (CGSize(width: textLayout.size.width + credibilityIconWidth + infoWidth, height: textLayout.size.height), { width in
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
                
                if hasPsaInfo {
                    let infoNode: InfoButtonNode
                    if let current = node.infoNode {
                        infoNode = current
                    } else {
                        infoNode = InfoButtonNode(pressed: { [weak node] in
                            guard let node = node else {
                                return
                            }
                            if let psaType = psaType, let infoNode = node.infoNode {
                                node.openPsa?(psaType, infoNode)
                            }
                        })
                        node.infoNode = infoNode
                        node.addSubnode(infoNode)
                    }
                    let infoButtonSize = CGSize(width: 32.0, height: 32.0)
                    let infoButtonFrame = CGRect(origin: CGPoint(x: width - infoButtonSize.width - 2.0, y: 1.0), size: infoButtonSize)
                    infoNode.frame = infoButtonFrame
                    infoNode.update(size: infoButtonFrame.size, theme: presentationData.theme, type: type)
                } else if let infoNode = node.infoNode {
                    node.infoNode = nil
                    infoNode.removeFromSupernode()
                }
                
                return node
            })
        }
    }
}
