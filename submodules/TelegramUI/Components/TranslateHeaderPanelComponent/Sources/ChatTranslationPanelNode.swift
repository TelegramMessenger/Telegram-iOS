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
import AccountContext
import MoreButtonNode
import ContextUI
import TranslateUI
import TelegramUIPreferences
import TelegramNotices
import PremiumUI
import ComponentFlow
import ComponentDisplayAdapters
import LocalMediaResources
import AppBundle
import TranslationLanguagesContextMenuContent

final class ChatTranslationPanelNode: ASDisplayNode {
    private let context: AccountContext
    private let close: () -> Void
    private let toggle: () -> Void
    private let controller: () -> ViewController?
    private let changeLanguage: (String) -> Void
    private let addDoNotTranslateLanguage: (String) -> Void
    
    private let button: HighlightableButtonNode
    private let buttonIconNode: ASImageNode
    private let buttonTextNode: ImmediateTextNode
    private let moreButton: MoreButtonNode
    private let closeButton: HighlightableButtonNode
    
    private var theme: PresentationTheme?
    
    private var currentInfo: TranslateHeaderPanelComponent.Info?
    
    init(context: AccountContext, close: @escaping () -> Void, toggle: @escaping () -> Void, changeLanguage: @escaping (String) -> Void, addDoNotTranslateLanguage: @escaping (String) -> Void, controller: @escaping () -> ViewController?) {
        self.context = context
        self.close = close
        self.toggle = toggle
        self.changeLanguage = changeLanguage
        self.addDoNotTranslateLanguage = addDoNotTranslateLanguage
        self.controller = controller
        
        self.button = HighlightableButtonNode()
        self.buttonIconNode = ASImageNode()
        self.buttonIconNode.displaysAsynchronously = false
        
        self.buttonTextNode = ImmediateTextNode()
        self.buttonTextNode.displaysAsynchronously = false
        
        let theme: PresentationTheme = context.sharedContext.currentPresentationData.with { $0 }.theme
        self.moreButton = MoreButtonNode(theme: theme)
        self.moreButton.updateColor(theme.chat.inputPanel.panelControlColor, transition: .immediate)
        self.moreButton.iconNode.enqueueState(.more, animated: false)
        self.moreButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
    
        super.init()

        self.clipsToBounds = true
        
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
    
    func updateLayout(
        width: CGFloat,
        info: TranslateHeaderPanelComponent.Info,
        theme: PresentationTheme,
        strings: PresentationStrings,
        transition: ContainedViewLayoutTransition
    ) -> CGFloat {
        let leftInset: CGFloat = 0.0
        let rightInset: CGFloat = 0.0
        
        let previousInfo = self.currentInfo
        self.currentInfo = info
        
        var themeUpdated = false
        if theme !== self.theme {
            themeUpdated = true
            self.theme = theme
        }
        
        if themeUpdated {
            self.buttonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/Translate"), color: theme.chat.inputPanel.panelControlColor)
            self.moreButton.theme = theme
            self.moreButton.updateColor(theme.chat.inputPanel.panelControlColor, transition: .immediate)
            self.closeButton.setImage(generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.chat.inputPanel.panelControlColor.cgColor)
                context.setLineWidth(1.33)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                context.strokePath()
                context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                context.strokePath()
            }), for: [])
        }

        var textUpdated = false
        if themeUpdated || previousInfo?.isActive != info.isActive {
            var languageCode = strings.baseLanguageCode
            let rawSuffix = "-raw"
            if languageCode.hasSuffix(rawSuffix) {
                languageCode = String(languageCode.dropLast(rawSuffix.count))
            }
            
            let toLang = info.toLang ?? languageCode
            let key = "Translation.Language.\(toLang)"
            let translateTitle: String
            if let string = strings.primaryComponent.dict[key] {
                translateTitle = strings.Conversation_Translation_TranslateTo(string).string
            } else {
                let languageLocale = Locale(identifier: languageCode)
                let toLanguage = languageLocale.localizedString(forLanguageCode: toLang) ?? ""
                translateTitle = strings.Conversation_Translation_TranslateToOther(toLanguage).string
            }
            
            let buttonText = info.isActive ? strings.Conversation_Translation_ShowOriginal : translateTitle
            if self.buttonTextNode.attributedText?.string != buttonText {
                textUpdated = true
            }
            self.buttonTextNode.attributedText = NSAttributedString(string: buttonText, font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlColor)
        }

        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 11.0 + rightInset
        
        var copyTextView: UIView?
        if textUpdated, transition.isAnimated {
            if let copyView = self.buttonTextNode.layer.snapshotContentTreeAsView(unhide: false) {
                copyTextView = copyView
                self.buttonTextNode.view.superview?.insertSubview(copyView, belowSubview: self.buttonTextNode.view)
                transition.updateAlpha(layer: copyView.layer, alpha: 0.0, completion: { [weak copyView] _ in
                    copyView?.removeFromSuperview()
                })
                ComponentTransition(transition).setBlur(layer: copyView.layer, radius: 8.0)
                
                ComponentTransition(transition).animateBlur(layer: self.buttonTextNode.layer, fromRadius: 8.0, toRadius: 0.0)
                self.buttonTextNode.alpha = 0.0
                transition.updateAlpha(layer: self.buttonTextNode.layer, alpha: 1.0)
            }
        }
                  
        let moreButtonSize = self.moreButton.measure(CGSize(width: 100.0, height: panelHeight))
        transition.updateFrame(node: self.moreButton, frame: CGRect(origin: CGPoint(x: width - contentRightInset - moreButtonSize.width, y: floorToScreenPixels((panelHeight - moreButtonSize.height) / 2.0) - 1.0), size: moreButtonSize))
     
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize)
        
        if info.isPremium {
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
            if let copyTextView {
                transition.updatePosition(layer: copyTextView.layer, position: buttonTextFrame.center)
            }
            self.buttonTextNode.bounds = CGRect(origin: CGPoint(), size: buttonTextFrame.size)
        }
        
        return panelHeight
    }
    
    @objc private func closePressed() {
        guard let info = self.currentInfo else {
            return
        }
        let isPremium = info.isPremium
        
        var translationAvailable = isPremium
        if case let .channel(channel) = info.peer, channel.flags.contains(.autoTranslateEnabled) {
            translationAvailable = true
        }
        
        if translationAvailable {
            self.close()
        } else if !isPremium {
            let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(accountManager: self.context.sharedContext.accountManager, count: -100, timestamp: Int32(Date().timeIntervalSince1970) + 60 * 60 * 24 * 7).startStandalone()
        }
    }
    
    @objc private func buttonPressed() {
        guard let info = self.currentInfo else {
            return
        }
        
        let isPremium = info.isPremium
        
        var translationAvailable = isPremium
        if case let .channel(channel) = info.peer, channel.flags.contains(.autoTranslateEnabled) {
            translationAvailable = true
        }
        
        if translationAvailable {
            self.toggle()
        } else if !info.isActive {
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
                self.controller()?.push(controller)
            }
        }
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard let info = self.currentInfo else {
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
        let fromLang = info.fromLang
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
            }, action: { [weak self] c, _ in
                guard let self else {
                    return
                }
                
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
                                    guard let self else {
                                        return
                                    }
                                    self.changeLanguage(language)
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
                
                guard let self, let info = self.currentInfo else {
                    return
                }
                self.addDoNotTranslateLanguage(info.fromLang)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_Translation_Hide, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                self?.close()
            })))
            
            items.append(.separator)
            
            let cocoonPath = getAppBundle().url(forResource: "Cocoon", withExtension: "tgs")?.path ?? ""
            let cocoonFile = TelegramMediaFile(
                fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: -123456789),
                partialReference: nil,
                resource: BundleResource(name: "Cocoon", path: cocoonPath),
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "application/x-tgsticker",
                size: nil,
                attributes: [
                    .FileName(fileName: "sticker.tgs"),
                    .CustomEmoji(isPremium: false, isSingleColor: true, alt: "", packReference: .animatedEmojiAnimations)
                ],
                alternativeRepresentations: []
            )

            let (cocoonText, entities) = parseCocoonMenuTextEntities(presentationData.strings.Conversation_Translation_CocoonInfo, emojiFileId: cocoonFile.fileId.id)
            items.append(.action(ContextMenuActionItem(text: cocoonText, entities: entities, entityFiles: [cocoonFile.fileId.id: cocoonFile], enableEntityAnimations: true, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                if let controller = self?.controller() {
                    let infoController = context.sharedContext.makeCocoonInfoScreen(context: context)
                    controller.push(infoController)
                }
            })))
            
            return ContextController.Items(content: .list(items))
        }
            
        if let controller = self.controller() {
            let contextController = makeContextController(context: context, presentationData: presentationData, source: .reference(TranslationContextReferenceContentSource(controller: controller, sourceNode: node)), items: items, gesture: gesture)
            controller.presentInGlobalOverlay(contextController)
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

private func parseCocoonMenuTextEntities(_ input: String, emojiFileId: Int64) -> (String, [MessageTextEntity]) {
    var output = ""

    var entities: [MessageTextEntity] = []

    var i = input.startIndex
    var outputCount = 0

    func utf16Len(_ s: String) -> Int {
        s.utf16.count
    }

    func peek(_ offset: Int) -> Character? {
        var idx = i
        for _ in 0..<offset {
            if idx == input.endIndex { return nil }
            idx = input.index(after: idx)
        }
        return idx < input.endIndex ? input[idx] : nil
    }

    var boldStartOut: Int? = nil
    while i < input.endIndex {
        let c = input[i]
        if c == "*", peek(1) == "*" {
            if let start = boldStartOut {
                let end = outputCount
                if end > start {
                    entities.append(MessageTextEntity(range: start..<end, type: .Bold))
                }
                boldStartOut = nil
            } else {
                boldStartOut = outputCount
            }
            i = input.index(i, offsetBy: 2)
            continue
        }

        if c == "[" {
            let labelStart = input.index(after: i)
            guard let closeBracket = input[labelStart...].firstIndex(of: "]") else {
                let s = String(c)
                output += s
                outputCount += utf16Len(s)
                i = input.index(after: i)
                continue
            }

            let afterBracket = input.index(after: closeBracket)
            guard afterBracket < input.endIndex, input[afterBracket] == "(" else {
                let s = String(c)
                output += s
                outputCount += utf16Len(s)
                i = input.index(after: i)
                continue
            }

            let urlStart = input.index(after: afterBracket)
            guard let closeParen = input[urlStart...].firstIndex(of: ")") else {
                let s = String(c)
                output += s
                outputCount += utf16Len(s)
                i = input.index(after: i)
                continue
            }

            let label = String(input[labelStart..<closeBracket])
        
            let labelOutStart = outputCount
            output += label
            let labelLen = utf16Len(label)
            outputCount += labelLen

            if !label.isEmpty {
                entities.append(MessageTextEntity(
                    range: labelOutStart ..< (labelOutStart + labelLen),
                    type: .Url
                ))
            }
            i = input.index(after: closeParen)
            continue
        }

        if c == "#" {
            let s = "#"
            output += s
            let len = utf16Len(s)
            entities.append(MessageTextEntity(
                range: outputCount ..< (outputCount + len),
                type: .CustomEmoji(stickerPack: nil, fileId: emojiFileId)
            ))

            outputCount += len
            i = input.index(after: i)
            continue
        }

        let s = String(c)
        output += s
        outputCount += utf16Len(s)
        i = input.index(after: i)
    }

    if let start = boldStartOut {
        let end = outputCount
        if end > start {
            entities.append(MessageTextEntity(range: start..<end, type: .Bold))
        }
    }

    return (output, entities)
}
