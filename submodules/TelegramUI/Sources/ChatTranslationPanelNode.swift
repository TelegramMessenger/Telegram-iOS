import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting
import TextFormat
import Markdown
import ChatPresentationInterfaceState
import AccountContext
import MoreButtonNode
import ContextUI
import TranslateUI

final class ChatTranslationPanelNode: ASDisplayNode {
    private let context: AccountContext
    
    private let separatorNode: ASDisplayNode
    
    private let button: HighlightableButtonNode
    private let buttonIconNode: ASImageNode
    private let buttonTextNode: ImmediateTextNode
    private let moreButton: MoreButtonNode
   
    private var theme: PresentationTheme?
   
    private var chatInterfaceState: ChatPresentationInterfaceState?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    init(context: AccountContext) {
        self.context = context
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.button = HighlightableButtonNode()
        self.buttonIconNode = ASImageNode()
        self.buttonIconNode.displaysAsynchronously = false
        
        self.buttonTextNode = ImmediateTextNode()
        self.buttonTextNode.displaysAsynchronously = false
        
        self.moreButton = MoreButtonNode(theme: context.sharedContext.currentPresentationData.with { $0 }.theme)
        self.moreButton.iconNode.enqueueState(.more, animated: false)
    
        super.init()

        self.clipsToBounds = true
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.button)
        self.addSubnode(self.moreButton)
        
        self.button.addSubnode(self.buttonIconNode)
        self.button.addSubnode(self.buttonTextNode)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
        self.moreButton.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.morePressed(node: strongSelf.moreButton.contextSourceNode, gesture: gesture)
            }
        }
    }
    
    func animateOut() {
        self.layer.animateBounds(from: self.bounds, to: self.bounds.offsetBy(dx: 0.0, dy: self.bounds.size.height), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let previousIsEnabled = self.chatInterfaceState?.translationState?.isEnabled
        self.chatInterfaceState = interfaceState
        
        var themeUpdated = false
        if interfaceState.theme !== self.theme {
            themeUpdated = true
            self.theme = interfaceState.theme
        }
        
        var isEnabledUpdated = false
        if previousIsEnabled != interfaceState.translationState?.isEnabled {
            isEnabledUpdated = true
        }
        
        if themeUpdated {
            self.buttonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/Translate"), color: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
            self.moreButton.theme = interfaceState.theme
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }

        if themeUpdated || isEnabledUpdated {
            if previousIsEnabled != nil && isEnabledUpdated {
                var offset: CGFloat = 30.0
                if interfaceState.translationState?.isEnabled == false {
                    offset *= -1
                }
                if let snapshotView = self.button.view.snapshotContentTree() {
                    snapshotView.frame = self.button.frame
                    self.button.supernode?.view.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.2,  removeOnCompletion: false, additive: true)
                    self.button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.button.layer.animatePosition(from: CGPoint(x: 0.0, y: -offset), to: CGPoint(), duration: 0.2, additive: true)
                }
            }
            
            var languageCode = interfaceState.strings.baseLanguageCode
            let rawSuffix = "-raw"
            if languageCode.hasSuffix(rawSuffix) {
                languageCode = String(languageCode.dropLast(rawSuffix.count))
            }
            let locale = Locale(identifier: languageCode)
            let toLang = interfaceState.translationState?.toLang ?? languageCode
            let toLanguage: String = locale.localizedString(forLanguageCode: toLang) ?? ""
            
            let buttonText = interfaceState.translationState?.isEnabled == true ? interfaceState.strings.Conversation_Translation_ShowOriginal : interfaceState.strings.Conversation_Translation_TranslateTo(toLanguage).string
            self.buttonTextNode.attributedText = NSAttributedString(string: buttonText, font: Font.regular(17.0), textColor: interfaceState.theme.rootController.navigationBar.accentTextColor)
        }

        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
                  
        let moreButtonSize = self.moreButton.measure(CGSize(width: 100.0, height: panelHeight))
        self.moreButton.frame = CGRect(origin: CGPoint(x: width - contentRightInset - moreButtonSize.width, y: floorToScreenPixels((panelHeight - moreButtonSize.height) / 2.0)), size: moreButtonSize)
     
        let buttonPadding: CGFloat = 10.0
        let buttonSpacing: CGFloat = 10.0
        let buttonTextSize = self.buttonTextNode.updateLayout(CGSize(width: width - contentRightInset - moreButtonSize.width, height: panelHeight))
        if let icon = self.buttonIconNode.image {
            let buttonSize = CGSize(width: buttonTextSize.width + icon.size.width + buttonSpacing + buttonPadding * 2.0, height: panelHeight)
            self.button.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - buttonSize.width) / 2.0), y: 0.0), size: buttonSize)
            self.buttonIconNode.frame = CGRect(origin: CGPoint(x: buttonPadding, y: floorToScreenPixels((buttonSize.height - icon.size.height) / 2.0)), size: icon.size)
            self.buttonTextNode.frame = CGRect(origin: CGPoint(x: buttonPadding + icon.size.width + buttonSpacing, y: floorToScreenPixels((buttonSize.height - buttonTextSize.height) / 2.0)), size: buttonTextSize)
        }

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc private func buttonPressed() {
        guard let translationState = self.chatInterfaceState?.translationState else {
            return
        }
        
        self.interfaceInteraction?.toggleTranslation(translationState.isEnabled ? .original : .translated)
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard let translationState = self.chatInterfaceState?.translationState else {
            return
        }
        
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var languageCode = presentationData.strings.baseLanguageCode
        let rawSuffix = "-raw"
        if languageCode.hasSuffix(rawSuffix) {
            languageCode = String(languageCode.dropLast(rawSuffix.count))
        }
        let locale = Locale(identifier: languageCode)
        let fromLanguage: String = locale.localizedString(forLanguageCode: translationState.fromLang) ?? ""
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_ChooseLanguage, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
        }, action: { c, _ in
            var subItems: [ContextMenuItem] = []
            
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
            }, action: { c, _ in
                c.popItems()
            })))
            subItems.append(.separator)

            let enLocale = Locale(identifier: "en")
            var languages: [(String, String, String)] = []
            var addedLanguages = Set<String>()
            for code in popularTranslationLanguages {
                if let title = enLocale.localizedString(forLanguageCode: code) {
                    let languageLocale = Locale(identifier: code)
                    let subtitle = languageLocale.localizedString(forLanguageCode: code) ?? title
                    let value = (code, title.capitalized, subtitle.capitalized)
                    if code == languageCode {
                        languages.insert(value, at: 0)
                    } else {
                        languages.append(value)
                    }
                    addedLanguages.insert(code)
                }
            }

//            for code in supportedTranslationLanguages {
//                if !addedLanguages.contains(code), let title = enLocale.localizedString(forLanguageCode: code) {
//                    let languageLocale = Locale(identifier: code)
//                    let subtitle = languageLocale.localizedString(forLanguageCode: code) ?? title
//                    let value = (code, title.capitalized, subtitle.capitalized)
//                    if code == languageCode {
//                        languages.insert(value, at: 0)
//                    } else {
//                        languages.append(value)
//                    }
//                }
//            }
            
            for (langCode, title, _) in languages {
                subItems.append(.action(ContextMenuActionItem(text: title , icon: { theme in
                    if translationState.toLang == langCode {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    } else {
                        return nil
                    }
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    self?.interfaceInteraction?.changeTranslationLanguage(langCode)
                })))
            }
            
            c.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
        })))
        
        items.append(.separator)
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_DoNotTranslate(fromLanguage).string, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, _ in
            c.dismiss(completion: nil)
            
            self?.interfaceInteraction?.addDoNotTranslateLanguage(translationState.fromLang)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_Hide, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, _ in
            c.dismiss(completion: nil)
            
            self?.interfaceInteraction?.hideTranslationPanel()
        })))

        if let controller = self.interfaceInteraction?.chatController() {
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(TranslationContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            self.interfaceInteraction?.presentGlobalOverlayController(contextController, nil)
        }
    }
}

private final class TranslationContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
