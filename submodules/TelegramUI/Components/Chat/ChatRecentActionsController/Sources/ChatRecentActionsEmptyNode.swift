import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import WallpaperBackgroundNode
import ChatPresentationInterfaceState

private let titleFont = Font.semibold(15.0)
private let textFont = Font.regular(13.0)

public final class ChatRecentActionsEmptyNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var chatWallpaper: TelegramWallpaper
    private var hasIcon: Bool
        
    private let backgroundNode: NavigationBackgroundNode
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var layoutParams: (CGSize, ChatPresentationData)?
    
    private var title: String = ""
    private var text: String = ""
    
    public init(theme: PresentationTheme, chatWallpaper: TelegramWallpaper, chatBubbleCorners: PresentationChatBubbleCorners, hasIcon: Bool) {
        self.theme = theme
        self.chatWallpaper = chatWallpaper
        self.hasIcon = hasIcon
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.allowsGroupOpacity = true
                
        self.addSubnode(self.backgroundNode)
        if hasIcon {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    public func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
    }
    
    public func updateLayout(presentationData: ChatPresentationData, backgroundNode: WallpaperBackgroundNode, size: CGSize, transition: ContainedViewLayoutTransition) {
        self.wallpaperBackgroundNode = backgroundNode
        self.layoutParams = (size, presentationData)
        
        let themeUpdated = self.theme !== presentationData.theme.theme
        self.theme = presentationData.theme.theme
        self.chatWallpaper = presentationData.theme.wallpaper
    
        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
        
        let insets = self.hasIcon ? UIEdgeInsets(top: 16.0, left: 16.0, bottom: 25.0, right: 16.0) : UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        
        let maxTextWidth = min(196.0, size.width - insets.left - insets.right - 18.0 * 2.0)
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let serviceColor = serviceMessageColorComponents(theme: self.theme, wallpaper: self.chatWallpaper)
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title, font: titleFont, textColor: serviceColor.primaryText), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let spacing: CGFloat = titleLayout.size.height.isZero ? 0.0 : 7.0
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.text, font: textFont, textColor: serviceColor.primaryText), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        let contentSize: CGSize
        let iconSize: CGSize
        if self.hasIcon {
            if themeUpdated || self.iconNode.image == nil {
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Recent Actions/Placeholder"), color: serviceColor.primaryText)
            }            
            iconSize = self.iconNode.image?.size ?? .zero
            contentSize = CGSize(width: max(titleLayout.size.width, textLayout.size.width) + insets.left + insets.right, height: 5.0 + insets.bottom + iconSize.height - 2.0 + titleLayout.size.height + spacing + textLayout.size.height)
        } else {
            iconSize = .zero
            contentSize = CGSize(width: max(titleLayout.size.width, textLayout.size.width) + insets.left + insets.right, height: insets.top + insets.bottom + titleLayout.size.height + spacing + textLayout.size.height)
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) / 2.0), y: floor((size.height - contentSize.height) / 2.0)), size: contentSize)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: min(14.0, self.backgroundNode.bounds.height / 2.0), transition: transition)
        
        let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((contentSize.width - iconSize.width) / 2.0), y: backgroundFrame.minY + 5.0), size: iconSize)
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        
        let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((contentSize.width - titleLayout.size.width) / 2.0), y: self.hasIcon ? iconFrame.maxY - 2.0 : backgroundFrame.minY + insets.top), size: titleLayout.size)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((contentSize.width - textLayout.size.width) / 2.0), y: titleFrame.maxY + spacing), size: textLayout.size)
        transition.updateFrame(node: self.textNode, frame: textFrame)
      
        let _ = titleApply()
        let _ = textApply()
        
        if backgroundNode.hasExtraBubbleBackground() == true {
            if self.backgroundContent == nil, let backgroundContent = backgroundNode.makeBubbleBackground(for: .free) {
                backgroundContent.clipsToBounds = true

                self.backgroundContent = backgroundContent
                self.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            self.backgroundNode.isHidden = true
            backgroundContent.cornerRadius = 14.0
            backgroundContent.frame = backgroundFrame
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        } else {
            self.backgroundNode.isHidden = false
        }
    }
    
    public func setup(title: String, text: String) {
        if self.title != title || self.text != text {
            self.title = title
            self.text = text
            if let (size, presentationData) = self.layoutParams, let wallpaperBackgroundNode = self.wallpaperBackgroundNode {
                self.updateLayout(presentationData: presentationData, backgroundNode: wallpaperBackgroundNode, size: size, transition: .immediate)
            }
        }
    }
}
