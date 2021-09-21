import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import Markdown

private let infoFont = Font.regular(14.0)
private let passwordFont = Font.regular(16.0)
private let buttonFont = Font.regular(17.0)

final class SecureIdAuthFormContentNode: ASDisplayNode, SecureIdAuthContentNode, UITextFieldDelegate {
    private let primaryLanguageByCountry: [String: String]
    private let requestedFields: [SecureIdRequestedFormField]
    private let fieldBackgroundNode: ASDisplayNode
    private let fieldNodes: [SecureIdAuthFormFieldNode]
    private let headerNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private let requestLayout: () -> Void
    private var validLayout: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, peer: Peer, privacyPolicyUrl: String?, form: SecureIdForm, primaryLanguageByCountry: [String: String], openField: @escaping (SecureIdParsedRequestedFormField) -> Void, openURL: @escaping (String) -> Void, openMention: @escaping (TelegramPeerMention) -> Void, requestLayout: @escaping () -> Void) {
        self.requestLayout = requestLayout
        
        self.primaryLanguageByCountry = primaryLanguageByCountry
        self.requestedFields = form.requestedFields
        self.fieldBackgroundNode = ASDisplayNode()
        self.fieldBackgroundNode.isLayerBacked = true
        self.fieldBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        
        var fieldNodes: [SecureIdAuthFormFieldNode] = []
        
        for (field, fieldValues, _) in parseRequestedFormFields(self.requestedFields, values: form.values, primaryLanguageByCountry: primaryLanguageByCountry) {
            fieldNodes.append(SecureIdAuthFormFieldNode(theme: theme, strings: strings, field: field, values: fieldValues, primaryLanguageByCountry: primaryLanguageByCountry, selected: {
                openField(field)
            }))
        }
        
        self.fieldNodes = fieldNodes
        
        self.headerNode = ImmediateTextNode()
        self.headerNode.displaysAsynchronously = false
        self.headerNode.attributedText = NSAttributedString(string: strings.Passport_RequestedInformation, font: infoFont, textColor: theme.list.sectionHeaderTextColor)
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.2
        
        let text: NSAttributedString
        if let privacyPolicyUrl = privacyPolicyUrl {
            let privacyPolicyAttributes = MarkdownAttributeSet(font: infoFont, textColor: theme.list.freeTextColor)
            let privacyPolicyLinkAttributes = MarkdownAttributeSet(font: infoFont, textColor: theme.list.itemAccentColor, additionalAttributes: [NSAttributedString.Key.underlineStyle.rawValue: NSUnderlineStyle.single.rawValue as NSNumber, TelegramTextAttributes.URL: privacyPolicyUrl])
            
            text = parseMarkdownIntoAttributedString(strings.Passport_PrivacyPolicy(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder), (EnginePeer(peer).addressName ?? "")).string.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: privacyPolicyAttributes, bold: privacyPolicyAttributes, link: privacyPolicyLinkAttributes, linkAttribute: { _ in
                return nil
            }), textAlignment: .center)
            
            
        } else {
            text = NSAttributedString(string: strings.Passport_AcceptHelp(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder), (peer.addressName ?? "")).string, font: infoFont, textColor: theme.list.freeTextColor, paragraphAlignment: .left)
        }
        self.textNode.attributedText = text
        
        super.init()
        
        self.textNode.linkHighlightColor = theme.list.itemAccentColor.withAlphaComponent(0.5)
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { attributes, _ in
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                openURL(url)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                openMention(mention)
            }
        }
        
        self.addSubnode(self.headerNode)
        self.addSubnode(self.fieldBackgroundNode)
        self.addSubnode(self.textNode)
        self.fieldNodes.forEach(self.addSubnode)
    }
    
    func updateValues(_ values: [SecureIdValueWithContext]) {
        var index = 0
        for (_, fieldValues, _) in parseRequestedFormFields(self.requestedFields, values: values, primaryLanguageByCountry: self.primaryLanguageByCountry) {
            if index < self.fieldNodes.count {
                self.fieldNodes[index].updateValues(fieldValues, primaryLanguageByCountry: self.primaryLanguageByCountry)
            }
            index += 1
        }
        self.requestLayout()
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout {
        let transition = self.validLayout == nil ? .immediate : transition
        self.validLayout = width
        
        var contentHeight: CGFloat = 0.0
        
        let headerSpacing: CGFloat = 6.0
        let headerSize = self.headerNode.updateLayout(CGSize(width: width - 14.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: headerSize))
        contentHeight += headerSize.height + headerSpacing
        
        let fieldsOrigin = contentHeight
        for i in 0 ..< self.fieldNodes.count {
            let fieldHeight = self.fieldNodes[i].updateLayout(width: width, hasPrevious: i != 0, hasNext: i != self.fieldNodes.count - 1, transition: transition)
            transition.updateFrame(node: self.fieldNodes[i], frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: fieldHeight)))
            contentHeight += fieldHeight
        }
        
        let fieldsHeight = contentHeight - fieldsOrigin
        
        let textSpacing: CGFloat = 6.0
        contentHeight += textSpacing
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - 14.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: 14.0, y: contentHeight), size: textSize))
        contentHeight += textSize.height
        
        transition.updateFrame(node: self.fieldBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: fieldsOrigin), size: CGSize(width: width, height: fieldsHeight)))
        
        return SecureIdAuthContentLayout(height: contentHeight, centerOffset: floor((contentHeight) / 2.0) - 34.0)
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func didAppear() {
    }
    
    func willDisappear() {
    }
    
    func frameForField(_ field: SecureIdParsedRequestedFormField) -> CGRect? {
        for fieldNode in self.fieldNodes {
            if fieldNode.field == field {
                return fieldNode.frame
            }
        }
        return nil
    }
    
    func highlightField(_ field: SecureIdParsedRequestedFormField) {
        for fieldNode in self.fieldNodes {
            if fieldNode.field == field {
                fieldNode.highlight()
            }
        }
    }
}

