import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import AccountContext
import TelegramStringFormatting
import ChatPresentationInterfaceState

final class WebpagePreviewAccessoryPanelNode: AccessoryPanelNode {
    private let webpageDisposable = MetaDisposable()
    
    private(set) var webpage: TelegramMediaWebpage
    private(set) var url: String
    
    let closeButton: HighlightableButtonNode
    let lineNode: ASImageNode
    let iconNode: ASImageNode
    let titleNode: TextNode
    private var titleString: NSAttributedString?
    
    let textNode: TextNode
    private var textString: NSAttributedString?
    
    var theme: PresentationTheme
    var strings: PresentationStrings
    
    private var validLayout: (size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState)?
    
    init(context: AccountContext, url: String, webpage: TelegramMediaWebpage, theme: PresentationTheme, strings: PresentationStrings) {
        self.url = url
        self.webpage = webpage
        self.theme = theme
        self.strings = strings
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = PresentationResourcesChat.chatInputPanelWebpageIconImage(theme)
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.updateWebpage()
    }
    
    deinit {
        self.webpageDisposable.dispose()
    }
    
    override func animateIn() {
        self.iconNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
    }
    
    override func animateOut() {
        self.iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.strings = strings
           
            if self.theme !== theme {
                self.theme = theme
                
                self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
                self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
                self.iconNode.image = PresentationResourcesChat.chatInputPanelWebpageIconImage(theme)
            }
            
            if let text = self.titleString?.string {
                self.titleString = NSAttributedString(string: text, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            }
            
            if let text = self.textString?.string {
                self.textString = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
            }
            
            self.updateWebpage()
            
            if let (size, inset, interfaceState) = self.validLayout {
                self.updateState(size: size, inset: inset, interfaceState: interfaceState)
            }
        }
    }
    
    func replaceWebpage(url: String, webpage: TelegramMediaWebpage) {
        if self.url != url || !self.webpage.isEqual(to: webpage) {
            self.url = url
            self.webpage = webpage
            self.updateWebpage()
        }
    }
    
    private func updateWebpage() {
        var authorName = ""
        var text = ""
        switch self.webpage.content {
            case .Pending:
                authorName = self.strings.Channel_NotificationLoading
                text = self.url
            case let .Loaded(content):
                if let contentText = content.text {
                    text = contentText
                } else {
                    if let file = content.file, let mediaKind = mediaContentKind(EngineMedia(file)) {
                        if content.type == "telegram_background" {
                            text = strings.Message_Wallpaper
                        } else if content.type == "telegram_theme" {
                            text = strings.Message_Theme
                        } else {
                            text = stringForMediaKind(mediaKind, strings: self.strings).0
                        }
                    } else if content.type == "telegram_theme" {
                        text = strings.Message_Theme
                    } else if content.type == "video" {
                        text = stringForMediaKind(.video, strings: self.strings).0
                    } else if let _ = content.image {
                        text = stringForMediaKind(.image, strings: self.strings).0
                    }
                }
                
                if let title = content.title {
                    authorName = title
                } else if let websiteName = content.websiteName {
                    authorName = websiteName
                } else {
                    authorName = content.displayUrl
                }
            
        }
        
        self.titleString = NSAttributedString(string: authorName, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
        self.textString = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
        
        if let (size, inset, interfaceState) = self.validLayout {
            self.updateState(size: size, inset: inset, interfaceState: interfaceState)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, inset, interfaceState)
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 45.0))
        let leftInset: CGFloat = 55.0
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - closeButtonSize.width - inset, y: 2.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
        if let icon = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
        }
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: self.titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: self.textString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 7.0), size: titleLayout.size)
        
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 25.0), size: textLayout.size)
        
        let _ = titleApply()
        let _ = textApply()
    }
    
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
}
