import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
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
import TelegramUIPreferences
import TelegramNotices
import PremiumUI

final class ChatTranslationPanelNode: ASDisplayNode {
    private let context: AccountContext
    
    private let separatorNode: ASDisplayNode
    
    private let button: HighlightableButtonNode
    private let buttonIconNode: ASImageNode
    private let buttonTextNode: ImmediateTextNode
    private let moreButton: MoreButtonNode
    private let closeButton: HighlightableButtonNode
    
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
        self.moreButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
    
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
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    func animateOut() {
        self.layer.animateBounds(from: self.bounds, to: self.bounds.offsetBy(dx: 0.0, dy: self.bounds.size.height), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, leftDisplayInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
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
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelEncircledCloseIconImage(interfaceState.theme), for: [])
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
            
            let toLang = interfaceState.translationState?.toLang ?? languageCode
            let key = "Translation.Language.\(toLang)"
            let translateTitle: String
            if let string = interfaceState.strings.primaryComponent.dict[key] {
                translateTitle = interfaceState.strings.Conversation_Translation_TranslateTo(string).string
            } else {
                let languageLocale = Locale(identifier: languageCode)
                let toLanguage = languageLocale.localizedString(forLanguageCode: toLang) ?? ""
                translateTitle = interfaceState.strings.Conversation_Translation_TranslateToOther(toLanguage).string
            }
                        
            let buttonText = interfaceState.translationState?.isEnabled == true ? interfaceState.strings.Conversation_Translation_ShowOriginal : translateTitle
            self.buttonTextNode.attributedText = NSAttributedString(string: buttonText, font: Font.regular(17.0), textColor: interfaceState.theme.rootController.navigationBar.accentTextColor)
        }

        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
                  
        let moreButtonSize = self.moreButton.measure(CGSize(width: 100.0, height: panelHeight))
        self.moreButton.frame = CGRect(origin: CGPoint(x: width - contentRightInset - moreButtonSize.width, y: floorToScreenPixels((panelHeight - moreButtonSize.height) / 2.0)), size: moreButtonSize)
     
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize)
        
        if interfaceState.isPremium {
            self.moreButton.isHidden = false
            self.closeButton.isHidden = true
        } else {
            self.moreButton.isHidden = true
            self.closeButton.isHidden = false
        }
        
        let buttonPadding: CGFloat = 10.0
        let buttonSpacing: CGFloat = 10.0
        let buttonTextSize = self.buttonTextNode.updateLayout(CGSize(width: width - contentRightInset - moreButtonSize.width, height: panelHeight))
        if let icon = self.buttonIconNode.image {
            let buttonSize = CGSize(width: buttonTextSize.width + icon.size.width + buttonSpacing + buttonPadding * 2.0, height: panelHeight)
            transition.updateFrame(node: self.button, frame: CGRect(origin: CGPoint(x: leftInset + floorToScreenPixels((width - leftInset - rightInset - buttonSize.width) / 2.0), y: 0.0), size: buttonSize))
            
            transition.updateFrame(node: self.buttonIconNode, frame: CGRect(origin: CGPoint(x: buttonPadding, y: floorToScreenPixels((buttonSize.height - icon.size.height) / 2.0)), size: icon.size))
            
            let buttonTextFrame = CGRect(origin: CGPoint(x: buttonPadding + icon.size.width + buttonSpacing, y: floorToScreenPixels((buttonSize.height - buttonTextSize.height) / 2.0)), size: buttonTextSize)
            transition.updatePosition(node: self.buttonTextNode, position: buttonTextFrame.center)
            self.buttonTextNode.bounds = CGRect(origin: CGPoint(), size: buttonTextFrame.size)
        }

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: leftDisplayInset, y: 0.0), size: CGSize(width: width - leftDisplayInset, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc private func closePressed() {
        let isPremium = self.chatInterfaceState?.isPremium ?? false
        
        var translationAvailable = isPremium
        if let channel = self.chatInterfaceState?.renderedPeer?.chatMainPeer as? TelegramChannel, channel.flags.contains(.autoTranslateEnabled) {
            translationAvailable = true
        }
        
        if translationAvailable {
            self.interfaceInteraction?.hideTranslationPanel()
        } else if !isPremium {
            let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(accountManager: self.context.sharedContext.accountManager, count: -100, timestamp: Int32(Date().timeIntervalSince1970) + 60 * 60 * 24 * 7).startStandalone()
        }
    }
    
    @objc private func buttonPressed() {
        guard let translationState = self.chatInterfaceState?.translationState else {
            return
        }
        
        let isPremium = self.chatInterfaceState?.isPremium ?? false
        
        var translationAvailable = isPremium
        if let channel = self.chatInterfaceState?.renderedPeer?.chatMainPeer as? TelegramChannel, channel.flags.contains(.autoTranslateEnabled) {
            translationAvailable = true
        }
        
        if translationAvailable {
            self.interfaceInteraction?.toggleTranslation(translationState.isEnabled ? .original : .translated)
        } else if !translationState.isEnabled {
            if !isPremium {
                let context = self.context
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumDemoScreen(context: context, subject: .translation, action: {
                    let controller = PremiumIntroScreen(context: context, source: .translation)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                self.interfaceInteraction?.chatController()?.push(controller)
            }
        }
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
       
        let doNotTranslateTitle: String
        let fromLang = translationState.fromLang
        let key = "Translation.Language.\(fromLang)"
        if let string = presentationData.strings.primaryComponent.dict[key] {
            doNotTranslateTitle = presentationData.strings.Conversation_Translation_DoNotTranslate(string).string
        } else {
            let languageLocale = Locale(identifier: languageCode)
            let fromLanguage = languageLocale.localizedString(forLanguageCode: fromLang) ?? ""
            doNotTranslateTitle = presentationData.strings.Conversation_Translation_DoNotTranslateOther(fromLanguage).string
        }
        
        let items: Signal<ContextController.Items, NoError> = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
        |> take(1)
        |> map { sharedData -> ContextController.Items in
            let settings: TranslationSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                settings = current
            } else {
                settings = TranslationSettings.defaultSettings
            }
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_ChooseLanguage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
            }, action: { c, _ in
                var addedLanguages = Set<String>()
                
                var topLanguages: [String] = []
                let langCode = normalizeTranslationLanguage(languageCode)
                
                var selectedLanguages: Set<String>
                if let ignoredLanguages = settings.ignoredLanguages {
                    selectedLanguages = Set(ignoredLanguages)
                } else {
                    selectedLanguages = Set([langCode])
                    for language in systemLanguageCodes() {
                        selectedLanguages.insert(language)
                    }
                }
                for code in supportedTranslationLanguages {
                    if selectedLanguages.contains(code) {
                        topLanguages.append(code)
                    }
                }
                
                topLanguages.append("")
                                
                var languages: [(String, String)] = []
                let languageLocale = Locale(identifier: langCode)
                
                for code in topLanguages {
                    if !addedLanguages.contains(code) {
                        let displayTitle = languageLocale.localizedString(forLanguageCode: code) ?? ""
                        let value = (code, displayTitle)
                        if code == languageCode {
                            languages.insert(value, at: 0)
                        } else {
                            languages.append(value)
                        }
                        addedLanguages.insert(code)
                    }
                }
                
                for code in supportedTranslationLanguages {
                    if !addedLanguages.contains(code) {
                        let displayTitle = languageLocale.localizedString(forLanguageCode: code) ?? ""
                        let value = (code, displayTitle)
                        if code == languageCode {
                            languages.insert(value, at: 0)
                        } else {
                            languages.append(value)
                        }
                        addedLanguages.insert(code)
                    }
                }
                          
                c?.pushItems(items: .single(ContextController.Items(
                    content: .custom(
                        TranslationLanguagesContextMenuContent(
                            context: self.context,
                            languages: languages, back: { [weak c] in
                                c?.popItems()
                            }, selectLanguage: { [weak self, weak c] language in
                                c?.dismiss(completion: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.interfaceInteraction?.changeTranslationLanguage(language)
                                })
                            }
                        )
                    )
                )))
            })))
            
            items.append(.separator)
            
            items.append(.action(ContextMenuActionItem(text: doNotTranslateTitle, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                self?.interfaceInteraction?.addDoNotTranslateLanguage(translationState.fromLang)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_Hide, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                self?.interfaceInteraction?.hideTranslationPanel()
            })))
            
            return ContextController.Items(content: .list(items))
        }
            
        if let controller = self.interfaceInteraction?.chatController() {
            let contextController = ContextController(presentationData: presentationData, source: .reference(TranslationContextReferenceContentSource(controller: controller, sourceNode: node)), items: items, gesture: gesture)
            self.interfaceInteraction?.presentGlobalOverlayController(contextController, nil)
        }
    }
}

private final class TranslationContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    var keepInPlace: Bool {
        return true
    }
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private let separatorHeight: CGFloat = 7.0

private final class TranslationLanguagesContextMenuContent: ContextControllerItemsContent {
    private final class BackButtonNode: HighlightTrackingButtonNode {
        let highlightBackgroundNode: ASDisplayNode
        let titleLabelNode: ImmediateTextNode
        let separatorNode: ASDisplayNode
        let iconNode: ASImageNode

        var action: (() -> Void)?

        private var theme: PresentationTheme?

        init() {
            self.highlightBackgroundNode = ASDisplayNode()
            self.highlightBackgroundNode.isAccessibilityElement = false
            self.highlightBackgroundNode.alpha = 0.0

            self.titleLabelNode = ImmediateTextNode()
            self.titleLabelNode.isAccessibilityElement = false
            self.titleLabelNode.maximumNumberOfLines = 1
            self.titleLabelNode.isUserInteractionEnabled = false

            self.iconNode = ASImageNode()
            self.iconNode.isAccessibilityElement = false

            self.separatorNode = ASDisplayNode()
            self.separatorNode.isAccessibilityElement = false

            super.init()

            self.addSubnode(self.separatorNode)
            self.addSubnode(self.highlightBackgroundNode)
            self.addSubnode(self.titleLabelNode)
            self.addSubnode(self.iconNode)

            self.isAccessibilityElement = true

            self.highligthedChanged = { [weak self] highlighted in
                guard let strongSelf = self else {
                    return
                }
                if highlighted {
                    strongSelf.highlightBackgroundNode.alpha = 1.0
                } else {
                    let previousAlpha = strongSelf.highlightBackgroundNode.alpha
                    strongSelf.highlightBackgroundNode.alpha = 0.0
                    strongSelf.highlightBackgroundNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                }
            }

            self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(size: CGSize, presentationData: PresentationData, isLast: Bool) {
            let standardIconWidth: CGFloat = 32.0
            let sideInset: CGFloat = 16.0
            let iconSideInset: CGFloat = 12.0

            if self.theme !== presentationData.theme {
                self.theme = presentationData.theme
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: presentationData.theme.contextMenu.primaryColor)

                self.accessibilityLabel = presentationData.strings.Common_Back
            }

            self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
            self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor

            self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)

            self.titleLabelNode.attributedText = NSAttributedString(string: presentationData.strings.Common_Back, font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
            let titleSize = self.titleLabelNode.updateLayout(CGSize(width: size.width - sideInset - standardIconWidth, height: 100.0))
            self.titleLabelNode.frame = CGRect(origin: CGPoint(x: sideInset + 36.0, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)

            if let iconImage = self.iconNode.image {
                let iconFrame = CGRect(origin: CGPoint(x: iconSideInset, y: floor((size.height - iconImage.size.height) / 2.0)), size: iconImage.size)
                self.iconNode.frame = iconFrame
            }

            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel))
            self.separatorNode.isHidden = isLast
        }
    }

    private final class LanguagesListNode: ASDisplayNode, ASScrollViewDelegate {
        private final class ItemNode: HighlightTrackingButtonNode {
            let context: AccountContext
            let highlightBackgroundNode: ASDisplayNode
            let titleLabelNode: ImmediateTextNode
            let separatorNode: ASDisplayNode

            let action: () -> Void

            private var language: String?

            init(context: AccountContext, action: @escaping () -> Void) {
                self.action = action
                self.context = context

                self.highlightBackgroundNode = ASDisplayNode()
                self.highlightBackgroundNode.isAccessibilityElement = false
                self.highlightBackgroundNode.alpha = 0.0

                self.titleLabelNode = ImmediateTextNode()
                self.titleLabelNode.isAccessibilityElement = false
                self.titleLabelNode.maximumNumberOfLines = 1
                self.titleLabelNode.isUserInteractionEnabled = false

                self.separatorNode = ASDisplayNode()
                self.separatorNode.isAccessibilityElement = false

                super.init()

                self.isAccessibilityElement = true

                self.addSubnode(self.separatorNode)
                self.addSubnode(self.highlightBackgroundNode)
                self.addSubnode(self.titleLabelNode)

                self.highligthedChanged = { [weak self] highlighted in
                    guard let strongSelf = self, let language = strongSelf.language, !language.isEmpty else {
                        return
                    }
                    if highlighted {
                        strongSelf.highlightBackgroundNode.alpha = 1.0
                    } else {
                        let previousAlpha = strongSelf.highlightBackgroundNode.alpha
                        strongSelf.highlightBackgroundNode.alpha = 0.0
                        strongSelf.highlightBackgroundNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                    }
                }

                self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
            }

            @objc private func pressed() {
                guard let language = self.language, !language.isEmpty else {
                    return
                }
                self.action()
            }
            
            private var displayTitle: String?
            func update(size: CGSize, presentationData: PresentationData, language: String, displayTitle: String, isLast: Bool, syncronousLoad: Bool) {
                let sideInset: CGFloat = 16.0

                if self.language != language {
                    self.language = language
                    self.displayTitle = displayTitle
                    
                    self.accessibilityLabel = "\(displayTitle)"
                }
                
                self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor

                self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)

                self.titleLabelNode.attributedText = NSAttributedString(string: self.displayTitle ?? "", font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
                let maxTextWidth: CGFloat = size.width - sideInset

                let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                self.titleLabelNode.frame = titleFrame

                if language == "" {
                    self.separatorNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
                    self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: separatorHeight))
                    self.separatorNode.isHidden = false
                } else {
                    self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                    self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel))
                    self.separatorNode.isHidden = isLast
                }
            }
        }

        private let context: AccountContext
        private let languages: [(String, String)]
        private let requestUpdate: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let selectLanguage: (String) -> Void

        private let scrollNode: ASScrollNode
        private var ignoreScrolling: Bool = false
        private var animateIn: Bool = false
        private var bottomScrollInset: CGFloat = 0.0

        private var presentationData: PresentationData?
        private var currentSize: CGSize?
        private var apparentHeight: CGFloat = 0.0

        private var itemNodes: [Int: ItemNode] = [:]

        init(
            context: AccountContext,
            languages: [(String, String)],
            requestUpdate: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            selectLanguage: @escaping (String) -> Void
        ) {
            self.context = context
            self.languages = languages
            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight
            self.selectLanguage = selectLanguage

            self.scrollNode = ASScrollNode()
            self.scrollNode.canCancelAllTouchesInViews = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.showsVerticalScrollIndicator = false
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }
            self.scrollNode.clipsToBounds = false

            super.init()

            self.addSubnode(self.scrollNode)
            self.scrollNode.view.delegate = self.wrappedScrollViewDelegate

            self.clipsToBounds = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateVisibleItems(animated: false, syncronousLoad: false)

            if let size = self.currentSize {
                var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
                apparentHeight = max(apparentHeight, 44.0)
                apparentHeight = min(apparentHeight, size.height)
                if self.apparentHeight != apparentHeight {
                    self.apparentHeight = apparentHeight

                    self.requestUpdateApparentHeight(self, .immediate)
                }
            }
        }

        private func updateVisibleItems(animated: Bool, syncronousLoad: Bool) {
            guard let size = self.currentSize else {
                return
            }
            guard let presentationData = self.presentationData else {
                return
            }
            let itemHeight: CGFloat = 44.0
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -180.0)

            var validIds = Set<Int>()

            let minVisibleIndex = max(0, Int(floor(visibleBounds.minY / itemHeight)))
            let maxVisibleIndex = Int(ceil(visibleBounds.maxY / itemHeight))
            
            var separatorIndex = 0
            for i in 0 ..< self.languages.count {
                if self.languages[i].0.isEmpty {
                    separatorIndex = i
                    break
                }
            }
            
            if minVisibleIndex <= maxVisibleIndex {
                for index in minVisibleIndex ... maxVisibleIndex {
                    if index < self.languages.count {
                        let height = self.languages[index].0.isEmpty ? separatorHeight : itemHeight
                        var itemFrame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(index) * itemHeight), size: CGSize(width: size.width, height: height))
                        if index > separatorIndex {
                            itemFrame.origin.y += separatorHeight - itemHeight
                        }
                        
                        let (languageCode, displayTitle) = self.languages[index]
                        validIds.insert(index)
                        
                        let itemNode: ItemNode
                        if let current = self.itemNodes[index] {
                            itemNode = current
                        } else {
                            let selectLanguage = self.selectLanguage
                            itemNode = ItemNode(context: self.context, action: {
                                selectLanguage(languageCode)
                            })
                            self.itemNodes[index] = itemNode
                            self.scrollNode.addSubnode(itemNode)
                        }
                        
                        itemNode.update(size: itemFrame.size, presentationData: presentationData, language: languageCode, displayTitle: displayTitle, isLast: index == self.languages.count - 1 || index == separatorIndex - 1, syncronousLoad: syncronousLoad)
                        itemNode.frame = itemFrame
                    }
                }
            }

            var removeIds: [Int] = []
            for (id, itemNode) in self.itemNodes {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemNode.removeFromSupernode()
                }
            }
            for id in removeIds {
                self.itemNodes.removeValue(forKey: id)
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var extendedScrollNodeFrame = self.scrollNode.frame
            extendedScrollNodeFrame.size.height += self.bottomScrollInset

            if extendedScrollNodeFrame.contains(point) {
                return self.scrollNode.view.hitTest(self.view.convert(point, to: self.scrollNode.view), with: event)
            }

            return super.hitTest(point, with: event)
        }

        func update(presentationData: PresentationData, constrainedSize: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (height: CGFloat, apparentHeight: CGFloat) {
            let itemHeight: CGFloat = 44.0

            self.presentationData = presentationData
            
            var separatorIndex = 0
            for i in 0 ..< self.languages.count {
                if self.languages[i].0.isEmpty {
                    separatorIndex = i
                    break
                }
            }
            
            var contentHeight: CGFloat
            if separatorIndex != 0 {
                contentHeight = CGFloat(self.languages.count - 1) * itemHeight + separatorHeight
            } else {
                contentHeight = CGFloat(self.languages.count) * itemHeight
            }
            let size = CGSize(width: constrainedSize.width, height: contentHeight)

            let containerSize = CGSize(width: size.width, height: min(constrainedSize.height, size.height))
            self.currentSize = containerSize

            self.ignoreScrolling = true

            if self.scrollNode.frame != CGRect(origin: CGPoint(), size: containerSize) {
                self.scrollNode.frame = CGRect(origin: CGPoint(), size: containerSize)
            }
            if self.scrollNode.view.contentInset.bottom != bottomInset {
                self.scrollNode.view.contentInset.bottom = bottomInset
            }
            self.bottomScrollInset = bottomInset
            let scrollContentSize = CGSize(width: size.width, height: size.height)
            if self.scrollNode.view.contentSize != scrollContentSize {
                self.scrollNode.view.contentSize = scrollContentSize
            }
            self.ignoreScrolling = false

            self.updateVisibleItems(animated: transition.isAnimated, syncronousLoad: !transition.isAnimated)

            self.animateIn = false

            var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
            apparentHeight = max(apparentHeight, 44.0)
            apparentHeight = min(apparentHeight, containerSize.height)
            self.apparentHeight = apparentHeight

            return (containerSize.height, apparentHeight)
        }
    }

    final class ItemsNode: ASDisplayNode, ContextControllerItemsNode {
        private let context: AccountContext
        private let languages: [(String, String)]
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ContainedViewLayoutTransition) -> Void

        private var presentationData: PresentationData

        private var backButtonNode: BackButtonNode?
        private var separatorNode: ASDisplayNode?

        private let currentTabIndex: Int = 0
        private var visibleTabNodes: [Int: LanguagesListNode] = [:]

        private let selectLanguage: (String) -> Void

        private(set) var apparentHeight: CGFloat = 0.0

        init(
            context: AccountContext,
            languages: [(String, String)],
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            back: (() -> Void)?,
            selectLanguage: @escaping (String) -> Void
        ) {
            self.context = context
            self.languages = languages
            self.selectLanguage = selectLanguage
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })

            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight

            if let back = back {
                self.backButtonNode = BackButtonNode()
                self.backButtonNode?.action = {
                    back()
                }
            }

            super.init()

            if self.backButtonNode != nil {
                self.separatorNode = ASDisplayNode()
            }

            if let backButtonNode = self.backButtonNode {
                self.addSubnode(backButtonNode)
            }
            if let separatorNode = self.separatorNode {
                self.addSubnode(separatorNode)
            }
        }

        func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat) {
            let constrainedSize = CGSize(width: min(220.0, constrainedWidth), height: min(604.0, maxHeight))

            var topContentHeight: CGFloat = 0.0
            if let backButtonNode = self.backButtonNode {
                let backButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: 44.0))
                backButtonNode.update(size: backButtonFrame.size, presentationData: self.presentationData, isLast: true)
                transition.updateFrame(node: backButtonNode, frame: backButtonFrame)
                topContentHeight += backButtonFrame.height
            }
            if let separatorNode = self.separatorNode {
                let separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: separatorHeight))
                separatorNode.backgroundColor = self.presentationData.theme.contextMenu.sectionSeparatorColor
                transition.updateFrame(node: separatorNode, frame: separatorFrame)
                topContentHeight += separatorFrame.height
            }

            var tabLayouts: [Int: (height: CGFloat, apparentHeight: CGFloat)] = [:]

            var visibleIndices: [Int] = []
            visibleIndices.append(self.currentTabIndex)

            let previousVisibleTabFrames: [(Int, CGRect)] = self.visibleTabNodes.map { key, value -> (Int, CGRect) in
                return (key, value.frame)
            }

            for index in visibleIndices {
                var tabTransition = transition
                let tabNode: LanguagesListNode
                var initialReferenceFrame: CGRect?
                if let current = self.visibleTabNodes[index] {
                    tabNode = current
                } else {
                    for (previousIndex, previousFrame) in previousVisibleTabFrames {
                        if index > previousIndex {
                            initialReferenceFrame = previousFrame.offsetBy(dx: constrainedSize.width, dy: 0.0)
                        } else {
                            initialReferenceFrame = previousFrame.offsetBy(dx: -constrainedSize.width, dy: 0.0)
                        }
                        break
                    }

                    tabNode = LanguagesListNode(
                        context: self.context,
                        languages: self.languages,
                        requestUpdate: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                strongSelf.requestUpdate(transition)
                            }
                        },
                        requestUpdateApparentHeight: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                strongSelf.requestUpdateApparentHeight(transition)
                            }
                        },
                        selectLanguage: self.selectLanguage
                    )
                    self.addSubnode(tabNode)
                    self.visibleTabNodes[index] = tabNode
                    tabTransition = .immediate
                }

                let tabLayout = tabNode.update(presentationData: presentationData, constrainedSize: CGSize(width: constrainedSize.width, height: constrainedSize.height - topContentHeight), bottomInset: bottomInset, transition: tabTransition)
                tabLayouts[index] = tabLayout
                let currentFractionalTabIndex = CGFloat(self.currentTabIndex)
                let xOffset: CGFloat = (CGFloat(index) - currentFractionalTabIndex) * constrainedSize.width
                let tabFrame = CGRect(origin: CGPoint(x: xOffset, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: tabLayout.height))
                tabTransition.updateFrame(node: tabNode, frame: tabFrame)
                if let initialReferenceFrame = initialReferenceFrame {
                    transition.animatePositionAdditive(node: tabNode, offset: CGPoint(x: initialReferenceFrame.minX - tabFrame.minX, y: 0.0))
                }
            }

            var contentSize = CGSize(width: constrainedSize.width, height: topContentHeight)
            var apparentHeight = topContentHeight

            if let tabLayout = tabLayouts[self.currentTabIndex] {
                contentSize.height += tabLayout.height
                apparentHeight += tabLayout.apparentHeight
            }

            return (contentSize, apparentHeight)
        }
    }

    let context: AccountContext
    let languages: [(String, String)]
    let back: (() -> Void)?
    let selectLanguage: (String) -> Void

    public init(
        context: AccountContext,
        languages: [(String, String)],
        back: (() -> Void)?,
        selectLanguage: @escaping (String) -> Void
    ) {
        self.context = context
        self.languages = languages
        self.back = back
        self.selectLanguage = selectLanguage
    }

    func node(
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerItemsNode {
        return ItemsNode(
            context: self.context,
            languages: self.languages,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight,
            back: self.back,
            selectLanguage: self.selectLanguage
        )
    }
}
