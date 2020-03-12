import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import AccountContext
import TelegramStringFormatting

final class WebpagePreviewAccessoryPanelNode: AccessoryPanelNode {
    private let webpageDisposable = MetaDisposable()
    
    private(set) var webpage: TelegramMediaWebpage
    private(set) var url: String
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: TextNode
    private var titleString: NSAttributedString?
    
    let textNode: TextNode
    private var textString: NSAttributedString?
    
    var theme: PresentationTheme
    var strings: PresentationStrings
    
    init(context: AccountContext, url: String, webpage: TelegramMediaWebpage, theme: PresentationTheme, strings: PresentationStrings) {
        self.url = url
        self.webpage = webpage
        self.theme = theme
        self.strings = strings
        
        self.closeButton = ASButtonNode()
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.updateWebpage()
    }
    
    deinit {
        self.webpageDisposable.dispose()
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.strings = strings
           
            if self.theme !== theme {
                self.theme = theme
                
                self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
                self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            }
            
            if let text = self.titleString?.string {
                self.titleString = NSAttributedString(string: text, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            }
            
            if let text = self.textString?.string {
                self.textString = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
            }
            
            self.updateWebpage()
            
            self.setNeedsLayout()
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
                    if let file = content.file, let mediaKind = mediaContentKind(file) {
                        if content.type == "telegram_background" {
                            text = strings.Message_Wallpaper
                        } else if content.type == "telegram_theme" {
                            text = strings.Message_Theme
                        } else {
                            text = stringForMediaKind(mediaKind, strings: self.strings).0
                        }
                    } else if content.type == "telegram_theme" {
                        text = strings.Message_Theme
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
        
        self.setNeedsLayout()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let leftInset: CGFloat = 55.0
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
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
