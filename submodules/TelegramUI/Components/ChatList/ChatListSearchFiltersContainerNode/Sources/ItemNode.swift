import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext

final class ItemNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private var titleBadgeView: UIImageView?
    private let buttonNode: HighlightTrackingButtonNode
    
    private var selectionFraction: CGFloat = 0.0
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
    
        let titleInset: CGFloat = 4.0
                
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                    
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func update(type: ChatListSearchFilter, displayNewBadge: Bool, presentationData: PresentationData, selectionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.selectionFraction = selectionFraction
        
        let title: String
        var titleBadge: String?
        let icon: UIImage?
        
        let color = presentationData.theme.chat.inputPanel.panelControlColor
        switch type {
        case .chats:
            title = presentationData.strings.ChatList_Search_FilterChats
            icon = nil
        case .topics:
            title = presentationData.strings.ChatList_Search_FilterChats
            icon = nil
        case .channels:
            title = presentationData.strings.ChatList_Search_FilterChannels
            icon = nil
        case .apps:
            title = presentationData.strings.ChatList_Search_FilterApps
            icon = nil
        case .globalPosts:
            title = presentationData.strings.ChatList_Search_FilterGlobalPosts
            if displayNewBadge {
                titleBadge = presentationData.strings.ChatList_ContextMenuBadgeNew
            }
            icon = nil
        case .media:
            title = presentationData.strings.ChatList_Search_FilterMedia
            icon = nil
        case .downloads:
            title = presentationData.strings.ChatList_Search_FilterDownloads
            icon = nil
        case .links:
            title = presentationData.strings.ChatList_Search_FilterLinks
            icon = nil
        case .files:
            title = presentationData.strings.ChatList_Search_FilterFiles
            icon = nil
        case .music:
            title = presentationData.strings.ChatList_Search_FilterMusic
            icon = nil
        case .voice:
            title = presentationData.strings.ChatList_Search_FilterVoice
            icon = nil
        case .instantVideo:
            title = presentationData.strings.ChatList_Search_FilterVoice
            icon = nil
        case .publicPosts:
            title = presentationData.strings.ChatList_Search_FilterPublicPosts
            icon = nil
        case let .peer(peerId, isGroup, displayTitle, _):
            title = displayTitle
            let image: UIImage?
            if isGroup {
                image = UIImage(bundleImageName: "Chat List/Search/Group")
            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                image = UIImage(bundleImageName: "Chat List/Search/Channel")
            } else {
                image = UIImage(bundleImageName: "Chat List/Search/User")
            }
            icon = generateTintedImage(image: image, color: color)
        case let .date(_, _, displayTitle):
            title = displayTitle
            icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Calendar"), color: color)
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(15.0), textColor: color)
        
        if let titleBadge {
            let titleBadgeView: UIImageView
            if let current = self.titleBadgeView {
                titleBadgeView = current
            } else {
                titleBadgeView = UIImageView()
                self.titleBadgeView = titleBadgeView
                self.view.addSubview(titleBadgeView)
                
                let labelText = NSAttributedString(string: titleBadge, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
                let labelBounds = labelText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
                let badgeSize = CGSize(width: labelSize.width + 8.0, height: labelSize.height + 2.0 + 1.0)
                titleBadgeView.image = generateImage(badgeSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    let rect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - UIScreenPixel * 2.0))
                    
                    context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5.0).cgPath)
                    context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                    context.fillPath()
                    
                    UIGraphicsPushContext(context)
                    labelText.draw(at: CGPoint(x: 4.0, y: 1.0 + UIScreenPixel))
                    UIGraphicsPopContext()
                })
            }
        } else if let titleBadgeView = self.titleBadgeView {
            self.titleBadgeView = nil
            titleBadgeView.removeFromSuperview()
        }
        
        self.buttonNode.accessibilityLabel = title
        if selectionFraction == 1.0 {
            self.buttonNode.accessibilityTraits = [.button, .selected]
        } else {
            self.buttonNode.accessibilityTraits = [.button]
        }
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            self.iconNode.image = icon
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var iconInset: CGFloat = 0.0
        if let image = self.iconNode.image {
            iconInset = 22.0
            self.iconNode.frame = CGRect(x: 0.0, y: 4.0 + floorToScreenPixels((height - image.size.height) / 2.0), width: image.size.width, height: image.size.height)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: -self.titleNode.insets.left + iconInset, y: self.titleNode.insets.top + floorToScreenPixels((height - titleSize.height) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        
        var width = titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right + iconInset
        
        if let titleBadgeView = self.titleBadgeView, let image = titleBadgeView.image {
            width += 4.0 + image.size.width
            titleBadgeView.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - image.size.height) * 0.5) + 1.0), size: image.size)
        }
        
        return width
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -sideInset, bottom: 0.0, right: -sideInset)
    }
}
