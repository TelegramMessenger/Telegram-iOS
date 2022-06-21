import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TextFormat
import AccountContext
import ShareController
import Markdown

final class LanguageLinkPreviewContentNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    init(context: AccountContext, localizationInfo: LocalizationInfo, theme: PresentationTheme, strings: PresentationStrings, openTranslationUrl: @escaping (String) -> Void) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.lineSpacing = 0.1
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        let completionScore = min(100, localizationInfo.translatedStringCount * 100 / max(1, localizationInfo.totalStringCount))
        
        let text: String
        if localizationInfo.totalStringCount == 0 {
            self.titleNode.attributedText = NSAttributedString(string: strings.ApplyLanguage_UnsufficientDataTitle, font: Font.medium(18.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
            text = strings.ApplyLanguage_UnsufficientDataText(localizationInfo.title).string
        } else {
            self.titleNode.attributedText = NSAttributedString(string: strings.ApplyLanguage_ChangeLanguageTitle, font: Font.medium(18.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
            if !localizationInfo.isOfficial {
                text = strings.ApplyLanguage_ChangeLanguageUnofficialText(localizationInfo.title, "\(completionScore)").string
            } else {
                text = strings.ApplyLanguage_ChangeLanguageOfficialText(localizationInfo.title).string
            }
        }
        let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.primaryTextColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: theme.actionSheet.primaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.controlAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        self.textNode.linkHighlightColor = theme.actionSheet.controlAccentColor.withAlphaComponent(0.5)
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                let url: String
                if localizationInfo.platformUrl.isEmpty {
                    url = localizationInfo.platformUrl
                } else {
                    url = "https://translations.telegram.org/\(localizationInfo.languageCode)/"
                }
                openTranslationUrl(url)
            }
        }
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let insets = UIEdgeInsets(top: 12.0, left: 10.0, bottom: 12.0 + bottomInset, right: 10.0)
        let titleSpacing: CGFloat = 12.0
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
