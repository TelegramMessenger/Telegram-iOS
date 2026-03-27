import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import Speak
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import UndoUI
import SwiftUI
import ResizableSheetComponent
import GlassBarButtonComponent
import ListSectionComponent
import ListActionItemComponent
import PlainButtonComponent
import ButtonComponent
import TextFormat
import Pasteboard
import ContextUI
import TranslationLanguagesContextMenuContent
import TelegramUIPreferences
import Markdown

private let translateToTag = GenericComponentViewTag()

private func generateExpandBackground(size: CGSize, color: UIColor) -> UIImage {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [color.withAlphaComponent(0.0).cgColor, color.cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 40.0, y: size.height), options: CGGradientDrawingOptions())
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(x: 40.0, y: 0.0), size: CGSize(width: size.width - 40.0, height: size.height)))
    })!
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let text: String
    let entities: [MessageTextEntity]
    let fromLanguage: String?
    let toLanguage: String
    let copyTranslation: ((String, [MessageTextEntity]) -> Void)?
    let replaceText: ((String, [MessageTextEntity]) -> Void)?
    let translateChat: ((String, String) -> Void)?
    let changeLanguage: (String, String, @escaping (String, String) -> Void) -> Void
    let expand: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        text: String,
        entities: [MessageTextEntity],
        fromLanguage: String?,
        toLanguage: String,
        copyTranslation: ((String, [MessageTextEntity]) -> Void)?,
        replaceText: ((String, [MessageTextEntity]) -> Void)?,
        translateChat: ((String, String) -> Void)?,
        changeLanguage: @escaping (String, String, @escaping (String, String) -> Void) -> Void,
        expand: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.text = text
        self.entities = entities
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.copyTranslation = copyTranslation
        self.replaceText = replaceText
        self.translateChat = translateChat
        self.changeLanguage = changeLanguage
        self.expand = expand
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.fromLanguage != rhs.fromLanguage {
            return false
        }
        if lhs.toLanguage != rhs.toLanguage {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        var fromLanguage: String?
        let text: String
        let entities: [MessageTextEntity]
        var textExpanded: Bool = false
        
        var toLanguage: String
        var tone: TranslationTone = .neutral
        
        var translatedText: (String, [MessageTextEntity])?
        
        private let expand: () -> Void
        
        private var translationDisposable = MetaDisposable()
        
        fileprivate var isSpeakingOriginalText: Bool = false
        fileprivate var isSpeakingTranslatedText: Bool = false
        private var speechHolder: SpeechSynthesizerHolder?
        fileprivate var availableSpeakLanguages: Set<String>
        
        fileprivate var moreBackgroundImage: (CGSize, UIImage, UIColor)?
        
        private let useAlternativeTranslation: Bool
        
        weak var controller: TranslateScreen?
        
        init(context: AccountContext, fromLanguage: String?, text: String, entities: [MessageTextEntity], toLanguage: String, expand: @escaping () -> Void) {
            self.context = context
            self.text = text
            self.entities = entities
            self.fromLanguage = fromLanguage
            self.toLanguage = toLanguage
            self.expand = expand
            self.availableSpeakLanguages = supportedSpeakLanguages()
            
            let translationConfiguration = TranslationConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            var useAlternativeTranslation = false
            switch translationConfiguration.manual {
            case .alternative:
                useAlternativeTranslation = true
            default:
                break
            }
            self.useAlternativeTranslation = useAlternativeTranslation
            
            super.init()
                        
            self.translationDisposable.set((self.translate(text: text, entities: entities, fromLang: fromLanguage, toLang: toLanguage) |> deliverOnMainQueue).start(next: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.translatedText = text
                strongSelf.updated(transition: .immediate)
            }, error: { error in
                
            }))
        }
        
        deinit {
            self.speechHolder?.stop()
            self.translationDisposable.dispose()
        }
        
        func translate(text: String, entities: [MessageTextEntity], fromLang: String?, toLang: String) -> Signal<(String, [MessageTextEntity])?, TranslationError> {
            if self.useAlternativeTranslation {
                return alternativeTranslateText(text: text, fromLang: fromLang, toLang: toLang)
            } else {
                return self.context.engine.messages.translate(text: text, toLang: toLang, entities: entities, tone: self.tone)
            }
        }
        
        func changeTone(_ tone: TranslationTone) {
            guard self.tone != tone else {
                return
            }
            self.tone = tone
            self.translatedText = nil
            self.updated(transition: .immediate)
            
            self.translationDisposable.set((self.translate(text: self.text, entities: self.entities, fromLang: self.fromLanguage, toLang: self.toLanguage) |> deliverOnMainQueue).start(next: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.translatedText = text
                strongSelf.updated(transition: .immediate)
            }, error: { error in
                
            }))
        }
        
        func changeLanguage(fromLanguage: String, toLanguage: String) {
            guard self.fromLanguage != fromLanguage || self.toLanguage != toLanguage else {
                return
            }
            self.fromLanguage = fromLanguage
            self.toLanguage = toLanguage
            self.translatedText = nil
            self.updated(transition: .immediate)
            
            self.translationDisposable.set((self.translate(text: self.text, entities: self.entities, fromLang: fromLanguage, toLang: toLanguage) |> deliverOnMainQueue).start(next: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.translatedText = text
                strongSelf.updated(transition: .immediate)
            }, error: { error in
                
            }))
        }
        
        func expandText() {
            self.textExpanded = true
            self.updated(transition: .immediate)
            
            self.expand()
        }
        
        func speakOriginalText() {
            if let speechHolder = self.speechHolder {
                self.speechHolder = nil
                speechHolder.stop()
            }
            
            if self.isSpeakingOriginalText {
                self.isSpeakingOriginalText = false
            } else {
                self.isSpeakingTranslatedText = false
                
                self.isSpeakingOriginalText = true
                self.speechHolder = speakText(context: self.context, text: self.text)
                self.speechHolder?.completion = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isSpeakingOriginalText = false
                    strongSelf.updated(transition: .immediate)
                }
            }
            self.updated(transition: .immediate)
        }
        
        func speakTranslatedText() {
            guard let translatedText = self.translatedText else {
                return
            }
            
            if let speechHolder = self.speechHolder {
                self.speechHolder = nil
                speechHolder.stop()
            }
            
            if self.isSpeakingTranslatedText {
                self.isSpeakingTranslatedText = false
            } else {
                self.isSpeakingOriginalText = false
                
                self.isSpeakingTranslatedText = true
                self.speechHolder = speakText(context: self.context, text: translatedText.0)
                self.speechHolder?.completion = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isSpeakingTranslatedText = false
                    strongSelf.updated(transition: .immediate)
                }
            }
            self.updated(transition: .immediate)
        }
        
        func presentLanguageSelection() {
            guard let controller = self.controller else {
                return
            }
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: translateToTag) else {
                return
            }
                
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            var languageCode = presentationData.strings.baseLanguageCode
            let rawSuffix = "-raw"
            if languageCode.hasSuffix(rawSuffix) {
                languageCode = String(languageCode.dropLast(rawSuffix.count))
            }
            
            let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] sharedData in
                guard let self else {
                    return
                }
                let settings: TranslationSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                    settings = current
                } else {
                    settings = TranslationSettings.defaultSettings
                }
                
                var addedLanguages = Set<String>()
                
                var topLanguages: [String] = []
                let langCode = normalizeTranslationLanguage(languageCode)
                
                topLanguages.append("tone_formal")
                topLanguages.append("tone_neutral")
                topLanguages.append("tone_casual")
                
                topLanguages.append("")
                
                var ignoredLanguages: Set<String>
                if let current = settings.ignoredLanguages {
                    ignoredLanguages = Set(current)
                } else {
                    ignoredLanguages = Set([langCode])
                    for language in systemLanguageCodes() {
                        ignoredLanguages.insert(language)
                    }
                }
                for code in supportedTranslationLanguages {
                    if ignoredLanguages.contains(code) {
                        topLanguages.append(code)
                    }
                }
                
                topLanguages.append(" ")
                                
                var languages: [(String, String)] = []
                let languageLocale = Locale(identifier: langCode)
                
                for code in topLanguages {
                    if !addedLanguages.contains(code) {
                        let displayTitle: String
                        if code.hasPrefix("tone_") {
                            switch code {
                            case "tone_formal":
                                displayTitle = "Formal"
                            case "tone_neutral":
                                displayTitle = "Neutral"
                            case "tone_casual":
                                displayTitle = "Casual"
                            default:
                                displayTitle = ""
                            }
                        } else {
                            displayTitle = languageLocale.localizedString(forLanguageCode: code) ?? ""
                        }
                        
                        let value = (code, displayTitle)
                        if code == languageCode {
                            languages.insert(value, at: 4)
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
                            languages.insert(value, at: 4)
                        } else {
                            languages.append(value)
                        }
                        addedLanguages.insert(code)
                    }
                }
                
                var selectedLanguages = Set<String>()
                selectedLanguages.insert("tone_\(self.tone.rawValue)")
                selectedLanguages.insert(self.toLanguage)
                
                var dismissImpl: (() -> Void)?
                let items = ContextController.Items(
                    content: .custom(
                        TranslationLanguagesContextMenuContent(
                            context: self.context,
                            languages: languages,
                            selectedLanguages: selectedLanguages,
                            back: nil,
                            selectLanguage: { [weak self] language in
                                guard let self else {
                                    return
                                }
                                if language.hasPrefix("tone_") {
                                    let tone = String(language.dropFirst(5))
                                    self.changeTone(TranslationTone(rawValue: tone)!)
                                } else {
                                    self.changeLanguage(fromLanguage: self.fromLanguage ?? "", toLanguage: language)
                                }
                                dismissImpl?()
                            }
                        )
                    )
                )
                
                let contextController = makeContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(items), gesture: nil)
                controller.presentInGlobalOverlay(contextController)
                
                dismissImpl = { [weak contextController] in
                    contextController?.dismiss()
                }
            })
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, fromLanguage: self.fromLanguage, text: self.text, entities: self.entities, toLanguage: self.toLanguage, expand: self.expand)
    }
    
    static var body: Body {
        let textBackground = Child(RoundedRectangle.self)
        
        let originalTitle = Child(PlainButtonComponent.self)
        let originalText = Child(MultilineTextComponent.self)
        
        let originalMoreBackground = Child(Image.self)
        let originalMoreButton = Child(Button.self)
        
        let originalSpeakButton = Child(Button.self)
        
        let translationTitle = Child(PlainButtonComponent.self)
        let translationText = Child(MultilineTextComponent.self)
        let translationPlaceholder = Child(RoundedRectangle.self)
        let translationSpeakButton = Child(Button.self)
        
        let textStripe = Child(Rectangle.self)
//        let textSection = Child(ListSectionComponent.self)
        let actionsSection = Child(ListSectionComponent.self)

        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = context.component.context.sharedContext.currentPresentationData.with { $0 }
            let component = context.component
            
            if state.controller == nil {
                state.controller = environment.controller() as? TranslateScreen
            }
            
            let sideInset: CGFloat = 16.0
            
            
            let textTopInset: CGFloat = 16.0
            let textSpacing: CGFloat = 5.0
            let itemSpacing: CGFloat = 20.0
            let textSideInset: CGFloat = 16.0

            
            var contentHeight: CGFloat = 82.0
            
            let textFont = Font.regular(20.0)
            let boldTextFont = Font.semibold(20.0)
            let italicTextFont = Font.with(size: 20.0, weight: .regular, traits: .italic)
            let boldItalicTextFont = Font.semiboldItalic(20.0)
            let fixedTextFont = Font.with(size: 20.0, design: .monospace)
            
            var languageCode = environment.strings.baseLanguageCode
            let rawSuffix = "-raw"
            if languageCode.hasSuffix(rawSuffix) {
                languageCode = String(languageCode.dropLast(rawSuffix.count))
            }
            let locale = Locale(identifier: languageCode)
            let fromLanguage: String
            if let languageCode = state.fromLanguage {
                fromLanguage = locale.localizedString(forLanguageCode: languageCode) ?? ""
            } else {
                fromLanguage = ""
            }
            
            let _ = sideInset
            let _ = fromLanguage
            
            let originalTitleString = parseMarkdownIntoAttributedString("Detected as **\(fromLanguage)**", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.list.itemSecondaryTextColor), bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.list.itemAccentColor), link: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.list.itemPrimaryTextColor), linkAttribute: { _ in return nil }))
            
            let originalTitle = originalTitle.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                MultilineTextComponent(
                                    text: .plain(originalTitleString),
                                    horizontalAlignment: .natural,
                                    maximumNumberOfLines: 1
                                )
                            )),
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                BundleIconComponent(name: "Item List/ContextDisclosureArrow", tintColor: theme.list.itemAccentColor, maxSize: CGSize(width: 8.0, height: 11.0))
                            ))
                        ], spacing: 3.0)
                    ),
                    action: {
                        component.changeLanguage(state.fromLanguage ?? "", state.toLanguage, { fromLang, toLang in
                            state.changeLanguage(fromLanguage: fromLang, toLanguage: toLang)
                        })
                    },
                    animateScale: false
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let originalAttributedText = stringWithAppliedEntities(state.text, entities: state.entities, baseColor: theme.list.itemPrimaryTextColor, linkColor: theme.list.itemPrimaryTextColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: italicTextFont, boldItalicFont: boldItalicTextFont, fixedFont: fixedTextFont, blockQuoteFont: textFont, message: nil)
                        
            let originalText = originalText.update(
                component: MultilineTextComponent(
                    text: .plain(originalAttributedText),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: state.textExpanded ? 0 : 1,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0 - (state.textExpanded ? 30.0 : 0.0), height: context.availableSize.height),
                transition: .immediate
            )
            
            var toLanguage = locale.localizedString(forLanguageCode: state.toLanguage) ?? ""
            if state.tone != .neutral {
                toLanguage += " (\(state.tone.rawValue.capitalized))"
            }
            let translationTitle = translationTitle.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: toLanguage, font: Font.semibold(13.0), textColor: theme.list.itemAccentColor, paragraphAlignment: .natural)),
                                    horizontalAlignment: .natural,
                                    maximumNumberOfLines: 1
                                )
                            )),
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                BundleIconComponent(name: "Item List/ContextDisclosureArrow", tintColor: theme.list.itemAccentColor, maxSize: CGSize(width: 8.0, height: 11.0))
                            ))
                        ], spacing: 3.0)
                    ),
                    action: { [weak state] in
                        state?.presentLanguageSelection()
//                        component.changeLanguage(state.fromLanguage ?? "", state.toLanguage, { fromLang, toLang in
//                            state.changeLanguage(fromLanguage: fromLang, toLanguage: toLang)
//                        })
                    },
                    animateScale: false,
                    tag: translateToTag
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let translationTextHeight: CGFloat
            
            var maybeTranslationText: _UpdatedChildComponent? = nil
            var maybeTranslationPlaceholder: _UpdatedChildComponent? = nil
            if let translatedText = state.translatedText {
                let attributedText = stringWithAppliedEntities(translatedText.0, entities: translatedText.1, baseColor: theme.list.itemAccentColor, linkColor: theme.list.itemAccentColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: italicTextFont, boldItalicFont: boldItalicTextFont, fixedFont: fixedTextFont, blockQuoteFont: textFont, message: nil)
                
                maybeTranslationText = translationText.update(
                    component: MultilineTextComponent(
                        text: .plain(attributedText),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0 - 30.0, height: context.availableSize.height),
                    transition: .immediate
                )
                translationTextHeight = maybeTranslationText?.size.height ?? 0.0
            } else {
                maybeTranslationPlaceholder = translationPlaceholder.update(
                    component: RoundedRectangle(color: theme.list.itemAccentColor.withAlphaComponent(0.17), cornerRadius: 6.0),
                    availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0 - 42.0, height: 12.0),
                    transition: .immediate
                )
                translationTextHeight = 22.0
            }
            
            let topInset = contentHeight
            let textBackgroundOrigin = CGPoint(x: sideInset, y: topInset)
                
            let textStripe = textStripe.update(
                component: Rectangle(color: theme.list.itemPlainSeparatorColor),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: UIScreenPixel),
                transition: .immediate
            )
            
            let textBackgroundSize = CGSize(width: context.availableSize.width - sideInset * 2.0, height: textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight + itemSpacing)
            
            let textBackground = textBackground.update(
                component: RoundedRectangle(color: theme.list.itemBlocksBackgroundColor, cornerRadius: 26.0),
                availableSize: textBackgroundSize,
                transition: context.transition
            )
            
            context.add(textBackground
                .position(CGPoint(x: textBackgroundOrigin.x + textBackgroundSize.width / 2.0, y: topInset + textBackgroundSize.height / 2.0))
            )
            
            context.add(textStripe
                .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + textStripe.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing))
            )
            
            context.add(originalTitle
                .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + originalTitle.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height / 2.0))
            )
            context.add(originalText
                .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + originalText.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height / 2.0))
            )
            
            if state.textExpanded {
                if let fromLanguage = state.fromLanguage, state.availableSpeakLanguages.contains(fromLanguage) {
                    var checkColor = theme.list.itemCheckColors.foregroundColor
                    if checkColor.rgb == theme.list.itemPrimaryTextColor.rgb {
                        checkColor = theme.list.plainBackgroundColor
                    }
                    
                    let originalSpeakButton = originalSpeakButton.update(
                        component: Button(
                            content: AnyComponent(ZStack([
                                AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                                    fillColor: theme.list.itemPrimaryTextColor,
                                    size: CGSize(width: 26.0, height: 26.0)
                                ))),
                                AnyComponentWithIdentity(id: "a", component: AnyComponent(PlayPauseIconComponent(
                                    state: state.isSpeakingOriginalText ? .pause : .play,
                                    tintColor: checkColor,
                                    size: CGSize(width: 20.0, height: 20.0)
                                ))),
                            ])),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                state.speakOriginalText()
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: CGSize(width: 26.0, height: 26.0),
                        transition: .immediate
                    )
                    
                    context.add(originalSpeakButton
                        .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalSpeakButton.size.width / 2.0 + 9.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height - originalSpeakButton.size.height / 2.0 - 2.0 + 12.0))
                    )
                }
            } else {
                let originalMoreButton = originalMoreButton.update(
                    component: Button(
                        content: AnyComponent(Text(text: strings.PeerInfo_BioExpand, font: Font.regular(17.0), color: theme.list.itemAccentColor)),
                        action: { [weak state] in
                            guard let state = state else {
                                return
                            }
                            state.expandText()
                        }
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                
                let originalMoreBackgroundSize = CGSize(width: originalMoreButton.size.width + 50.0, height: originalMoreButton.size.height)
                let originalMoreBackgroundImage: UIImage
                let backgroundColor = theme.list.itemBlocksBackgroundColor
                if let (size, image, color) = state.moreBackgroundImage, size == originalMoreBackgroundSize && color == backgroundColor {
                    originalMoreBackgroundImage = image
                } else {
                    originalMoreBackgroundImage = generateExpandBackground(size: originalMoreBackgroundSize, color: backgroundColor)
                    state.moreBackgroundImage = (originalMoreBackgroundSize, originalMoreBackgroundImage, backgroundColor)
                }
                let originalMoreBackground = originalMoreBackground.update(
                    component: Image(image: originalMoreBackgroundImage, tintColor: backgroundColor),
                    availableSize: originalMoreBackgroundSize,
                    transition: .immediate
                )
                
                context.add(originalMoreBackground
                    .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalMoreBackground.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalMoreBackground.size.height / 2.0 + 2.0))
                )
                
                context.add(originalMoreButton
                    .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalMoreButton.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height / 2.0 + 1.0 - UIScreenPixel))
                )
            }
            
            context.add(translationTitle
                .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationTitle.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height / 2.0))
            )
            
            if let translationText = maybeTranslationText {
                context.add(translationText
                    .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationText.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationText.size.height / 2.0))
                )
                
                if state.availableSpeakLanguages.contains(state.toLanguage) {
                    let translationSpeakButton = translationSpeakButton.update(
                        component: Button(
                            content: AnyComponent(ZStack([
                                AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                                    fillColor: theme.list.itemAccentColor,
                                    size: CGSize(width: 26.0, height: 26.0)
                                ))),
                                AnyComponentWithIdentity(id: "a", component: AnyComponent(PlayPauseIconComponent(
                                    state: state.isSpeakingTranslatedText ? .pause : .play,
                                    tintColor: theme.list.itemCheckColors.foregroundColor,
                                    size: CGSize(width: 20.0, height: 20.0)
                                ))),
                            ])),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                state.speakTranslatedText()
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: CGSize(width: 26.0, height: 26.0),
                        transition: .immediate
                    )
                                    
                    context.add(translationSpeakButton
                        .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - translationSpeakButton.size.width / 2.0 + 9.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight - translationSpeakButton.size.height / 2.0 - 2.0 + 12.0))
                        .appear(.default())
                        .disappear(.default())
                    )
                }
            } else if let translationPlaceholder = maybeTranslationPlaceholder {
                context.add(translationPlaceholder
                    .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationPlaceholder.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationPlaceholder.size.height / 2.0 + 4.0))
                )
            }
            
            contentHeight += textBackgroundSize.height
            contentHeight += 24.0
            
//            let textSectionItems: [AnyComponentWithIdentity<Empty>] = []
//            let textSection = textSection.update(
//                component: ListSectionComponent(
//                    theme: theme,
//                    style: .glass,
//                    header: nil,
//                    footer: nil,
//                    items: textSectionItems
//                ),
//                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
//                transition: context.transition
//            )
//            context.add(textSection
//                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + textSection.size.height / 2.0))
//            )
//            contentHeight += textSection.size.height
//            contentHeight += 24.0
            
            var actionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if let replaceText = component.replaceText {
                actionsSectionItems.append(AnyComponentWithIdentity(id: "replace", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Replace with Translation",
                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        )
                    ),
                    leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Replace", tintColor: theme.list.itemAccentColor))), false),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        replaceText(state.translatedText?.0 ?? state.text, state.translatedText?.1 ?? state.entities)
                        component.dismiss()
                    }
                ))))
            }
            if let copyTranslation = component.copyTranslation {
                actionsSectionItems.append(AnyComponentWithIdentity(id: "copy", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Translate_CopyTranslation,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        )
                    ),
                    leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: theme.list.itemAccentColor))), false),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        copyTranslation(state.translatedText?.0 ?? "", state.translatedText?.1 ?? [])
                    }
                ))))
            }
            if let translateChat = component.translateChat {
                actionsSectionItems.append(AnyComponentWithIdentity(id: "translate", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Translate Entire Chat",
                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        )
                    ),
                    leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Translate", tintColor: theme.list.itemAccentColor))), false),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        translateChat(state.fromLanguage ?? "", state.toLanguage)
                        component.dismiss()
                    }
                ))))
            }
            
            if !actionsSectionItems.isEmpty {
                let actionsSection = actionsSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: actionsSectionItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(actionsSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + actionsSection.size.height / 2.0))
                )
                contentHeight += actionsSection.size.height
            }
                        
            contentHeight += 32.0
            contentHeight += 52.0 + 30.0
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class TranslateSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let text: String
    private let entities: [MessageTextEntity]
    private let fromLanguage: String?
    private let toLanguage: String
    private let copyTranslation: ((String, [MessageTextEntity]) -> Void)?
    private let replaceText: ((String, [MessageTextEntity]) -> Void)?
    private let translateChat: ((String, String) -> Void)?
    private let changeLanguage: (String, String, @escaping (String, String) -> Void) -> Void
    private let openCocoonInfo: () -> Void
    
    init(
        context: AccountContext,
        text: String,
        entities: [MessageTextEntity],
        fromLanguage: String?,
        toLanguage: String,
        copyTranslation: ((String, [MessageTextEntity]) -> Void)?,
        replaceText: ((String, [MessageTextEntity]) -> Void)?,
        translateChat: ((String, String) -> Void)? = nil,
        changeLanguage: @escaping (String, String, @escaping (String, String) -> Void) -> Void,
        openCocoonInfo: @escaping () -> Void
    ) {
        self.context = context
        self.text = text
        self.entities = entities
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.copyTranslation = copyTranslation
        self.replaceText = replaceText
        self.translateChat = translateChat
        self.changeLanguage = changeLanguage
        self.openCocoonInfo = openCocoonInfo
    }
    
    static func ==(lhs: TranslateSheetComponent, rhs: TranslateSheetComponent) -> Bool {
        return true
    }
        
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            
            let openCocoonInfo = context.component.openCocoonInfo
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        text: context.component.text,
                        entities: context.component.entities,
                        fromLanguage: context.component.fromLanguage,
                        toLanguage: context.component.toLanguage,
                        copyTranslation: context.component.copyTranslation,
                        replaceText: context.component.replaceText,
                        translateChat: context.component.translateChat,
                        changeLanguage: context.component.changeLanguage,
                        expand: {},
                        dismiss: {
                            dismiss(true)
                        }
                    )),
                    titleItem: AnyComponent(
                        VStack([
                            AnyComponentWithIdentity(id: "title", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: "Translation", font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor)))
                            )),
                            AnyComponentWithIdentity(id: "subtitle", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: "powered by Cocoon", font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)))
                            ))
                        ], spacing: 1.0)
                    ),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "info", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Question",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                openCocoonInfo()
                            }
                        )
                    ),
                    bottomItem: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: theme.list.itemCheckColors.fillColor,
                                foreground: theme.list.itemCheckColors.foregroundColor,
                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(
                                    ButtonTextContentComponent(
                                        text: strings.Common_OK,
                                        badge: 0,
                                        textColor: theme.list.itemCheckColors.foregroundColor,
                                        badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                        badgeForeground: theme.list.itemCheckColors.fillColor
                                    )
                                )
                            ),
                            action: {
                                dismiss(true)
                            }
                        )
                    ),
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: 0.0,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class TranslateScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public var pushController: (ViewController) -> Void = { _ in }
    public var presentController: (ViewController) -> Void = { _ in }
        
    public init(
        context: AccountContext,
        forceTheme: PresentationTheme? = nil,
        text: String,
        entities: [MessageTextEntity] = [],
        canCopy: Bool,
        fromLanguage: String?,
        toLanguage: String? = nil,
        ignoredLanguages: [String]? = nil,
        replaceText: ((String, [MessageTextEntity]) -> Void)? = nil,
        translateChat: ((String, String) -> Void)? = nil
    ) {
        self.context = context
        
        let theme: ViewControllerComponentContainer.Theme
        if let forceTheme {
            theme = .custom(forceTheme)
        } else {
            theme = .default
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var baseLanguageCode = presentationData.strings.baseLanguageCode
        let rawSuffix = "-raw"
        if baseLanguageCode.hasSuffix(rawSuffix) {
            baseLanguageCode = String(baseLanguageCode.dropLast(rawSuffix.count))
        }
        
        let dontTranslateLanguages = effectiveIgnoredTranslationLanguages(context: context, ignoredLanguages: ignoredLanguages)
        
        var toLanguage = toLanguage ?? baseLanguageCode
        if toLanguage == fromLanguage {
            if fromLanguage == "en" {
                toLanguage = dontTranslateLanguages.first(where: { $0 != "en" }) ?? "en"
            } else {
                toLanguage = "en"
            }
            if toLanguage == "en" && fromLanguage == "en" {
                if let anyOtherLanguage = NSLocale.preferredLanguages.first(where: { !$0.hasPrefix("en-") }) {
                    toLanguage = anyOtherLanguage
                }
            }
        }
        
        toLanguage = normalizeTranslationLanguage(toLanguage)
        
        var copyTranslationImpl: ((String, [MessageTextEntity]) -> Void)?
        var changeLanguageImpl: ((String, String, @escaping (String, String) -> Void) -> Void)?
        var openCocoonInfoImpl: (() -> Void)?
        
        super.init(
            context: context,
            component: TranslateSheetComponent(
                context: context,
                text: text,
                entities: entities,
                fromLanguage: fromLanguage,
                toLanguage: toLanguage,
                copyTranslation: !canCopy ? nil : { text, entities in
                    copyTranslationImpl?(text, entities)
                },
                replaceText: replaceText,
                translateChat: translateChat,
                changeLanguage: { fromLang, toLang, completion in
                    changeLanguageImpl?(fromLang, toLang, completion)
                },
                openCocoonInfo: {
                    openCocoonInfoImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: theme
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        copyTranslationImpl = { [weak self] text, entities in
            storeMessageTextInPasteboard(text, entities: entities)
            
            let content = UndoOverlayContent.copy(text: presentationData.strings.Conversation_TextCopied)
            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            self?.dismissAnimated()
        }

        changeLanguageImpl = { [weak self] fromLang, toLang, completion in
            let pushController = self?.pushController
            let presentController = self?.presentController
            let controller = languageSelectionController(context: context, forceTheme: forceTheme, fromLanguage: fromLang, toLanguage: toLang, completion: { fromLang, toLang in
                let controller = TranslateScreen(context: context, forceTheme: forceTheme, text: text, entities: entities, canCopy: canCopy, fromLanguage: fromLang, toLanguage: toLang, ignoredLanguages: ignoredLanguages, replaceText: replaceText)
                controller.pushController = pushController ?? { _ in }
                controller.presentController = presentController ?? { _ in }
                presentController?(controller)
            })
            
            self?.dismissAnimated()
            
            pushController?(controller)
        }
        
        openCocoonInfoImpl = { [weak self] in
            let controller = context.sharedContext.makeCocoonInfoScreen(context: context)
            self?.pushController(controller)
        }
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

public func presentTranslateScreen(
    context: AccountContext,
    text: String,
    entities: [MessageTextEntity] = [],
    canCopy: Bool,
    fromLanguage: String?,
    toLanguage: String? = nil,
    isExpanded: Bool = false,
    ignoredLanguages: [String]? = nil,
    replaceText: ((String, [MessageTextEntity]) -> Void)? = nil,
    translateChat: ((String, String) -> Void)? = nil,
    pushController: @escaping (ViewController) -> Void = { _ in },
    presentController: @escaping (ViewController) -> Void = { _ in },
    wasDismissed: (() -> Void)? = nil,
    display: (ViewController) -> Void
) {
    let translationConfiguration = TranslationConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    var useSystemTranslation = false
    switch translationConfiguration.manual {
    case .system:
        if #available(iOS 18.0, *) {
            useSystemTranslation = true
        }
    default:
        break
    }
    
    if useSystemTranslation {
        presentSystemTranslateScreen(context: context, text: text)
    } else {
        let controller = TranslateScreen(context: context, text: text, entities: entities, canCopy: canCopy, fromLanguage: fromLanguage, toLanguage: toLanguage, ignoredLanguages: ignoredLanguages, replaceText: replaceText, translateChat: translateChat)
        controller.pushController = pushController
        controller.presentController = presentController
        controller.wasDismissed = wasDismissed
        display(controller)
    }
}

private func presentSystemTranslateScreen(context: AccountContext, text: String) {
    if #available(iOS 18.0, *), let rootViewController = context.sharedContext.mainWindow?.viewController?.view.window?.rootViewController {
        var dismissImpl: (() -> Void)?
        let pickerView = TranslateScreenHostingView(text: text, completionHandler: { [weak rootViewController] in
            DispatchQueue.main.async(execute: {
                guard let presentedController = rootViewController?.presentedViewController, presentedController.isBeingDismissed == false else { return }
                dismissImpl?()
            })
        })
        let hostingController = UIHostingController(rootView: pickerView)
        hostingController.view.isHidden = true
        hostingController.modalPresentationStyle = .overCurrentContext
        rootViewController.present(hostingController, animated: true)
        dismissImpl = { [weak hostingController] in
            Queue.mainQueue().after(0.4, {
                hostingController?.dismiss(animated: false)
            })
        }
    }
}

@available(iOS 18.0, *)
struct TranslateScreenHostingView: View {
    @State var presented = true
    var text: String
    var handler: () -> Void
    
    init(text: String, completionHandler: @escaping () -> Void) {
        self.text = text
        self.handler = completionHandler
    }
    
    var body: some View {
        Spacer()
            .translationPresentation(
                isPresented: $presented,
                text: text
            )
            .onChange(of: presented) { newValue in
                if newValue == false {
                    handler()
                }
            }
    }
}

private final class GiftViewContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
