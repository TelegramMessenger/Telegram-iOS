import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

final class LanguageLinkPreviewContentNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    init(account: Account, localizationInfo: LocalizationInfo, theme: PresentationTheme, strings: PresentationStrings, openTranslationUrl: @escaping (String) -> Void) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.lineSpacing = 0.1
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.titleNode.attributedText = NSAttributedString(string: "Change Language?", font: Font.medium(20.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        
        let completionScore = localizationInfo.translatedStringCount * 100 / max(1, localizationInfo.totalStringCount)
        
        let text: String
        if localizationInfo.translatedStringCount == 0 {
            self.titleNode.isHidden = true
            text = "This language is not available yet."
        } else {
            text = "You are about to apply a custom language pack \(localizationInfo.title) that is \(completionScore)% complete.\nThis will translate the entire interface. You can suggest corrections in the [translation panel](https://translations.telegram.org/\(localizationInfo.languageCode)/).\nYou can change your language back at any time in Settings."
        }
        let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.primaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.controlAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        self.textNode.linkHighlightColor = theme.actionSheet.controlAccentColor.withAlphaComponent(0.5)
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                openTranslationUrl("https://translations.telegram.org/\(localizationInfo.languageCode)/")
            }
        }
        
        //self.textNode.attributedText = NSAttributedString(string: "", font: Font.regular(15.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let insets = UIEdgeInsets(top: 12.0, left: 10.0, bottom: 12.0 + bottomInset, right: 10.0)
        let titleSpacing: CGFloat = 7.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: .greatestFiniteMagnitude))
        
        let nodeHeight: CGFloat
        if !self.titleNode.isHidden {
            nodeHeight = titleSize.height + titleSpacing + textSize.height + insets.top + insets.bottom
        } else {
            nodeHeight = textSize.height + insets.top + insets.bottom
        }
        
        let verticalOrigin = size.height - nodeHeight
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: verticalOrigin + insets.top), size: titleSize))
        let textOrigin: CGFloat
        if !self.titleNode.isHidden {
            textOrigin = verticalOrigin + insets.top + titleSize.height + titleSpacing
        } else {
            textOrigin = verticalOrigin + insets.top
        }
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: textOrigin), size: textSize))
        
        self.contentOffsetUpdated?(-size.height + nodeHeight - 64.0, transition)
    }
    
    func updateSelectedPeers() {
    }
}
