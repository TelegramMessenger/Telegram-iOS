import Foundation
import NaturalLanguage
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import AccountContext
import MultilineTextComponent
import BundleIconComponent
import TelegramCore
import TranslateUI
import TooltipComponent
import Markdown
import PlainButtonComponent
import TextFieldComponent

private let languageRecognizer = NLLanguageRecognizer()

enum LocalizedLanguageNameKind {
    case neutral
    case translateFrom
    case translateTo
}

func localizedLanguageName(strings: PresentationStrings, language: String, kind: LocalizedLanguageNameKind) -> String {
    var result: String?
    
    switch kind {
    case .neutral:
        if let value = strings.primaryComponent.dict["Translation.Language.\(language)"] {
            result = value
        }
    case .translateFrom:
        if let value = strings.primaryComponent.dict["Translation.LanguageFrom.\(language)"] {
            result = value
        }
    case .translateTo:
        if let value = strings.primaryComponent.dict["Translation.LanguageTo.\(language)"] {
            result = value
        }
    }
    if result == nil {
        if let value = strings.primaryComponent.dict["Translation.Language.\(language)"] {
            result = value
        }
    }
    if result == nil {
        let languageLocale = Locale(identifier: language)
        result = languageLocale.localizedString(forLanguageCode: language)?.capitalized
    }
    return result ?? ""
}

final class TextProcessingTranslateContentComponent: Component {
    enum Mode: Equatable {
        case translate(ignoredLanguages: [String])
        case stylize(isComposeWithAI: Bool)
        case fix
        case preview(from: ComposedRichMessage?, to: ComposedRichMessage?, authorPeer: EnginePeer?, userCount: Int, isRequesting: Bool)
    }
    
    final class ExternalState {
        fileprivate(set) var sourceLanguage: String?
        fileprivate(set) var sectionHeader: AnyComponentWithIdentity<Empty>?
        fileprivate(set) var sectionFooter: AnyComponentWithIdentity<Empty>?
        fileprivate(set) var promptText: String = ""
        
        fileprivate(set) var result: (language: String, text: ComposedRichMessage?, textCorrectionRanges: [Range<Int>])? = nil {
            didSet {
                if self.result?.language != oldValue?.language || self.result?.text != oldValue?.text {
                    self.resultUpdated?(self.result)
                }
            }
        }
        var resultUpdated: (((language: String, text: ComposedRichMessage?, textCorrectionRanges: [Range<Int>])?) -> Void)?
        var promptTextUpdated: (() -> Void)?
        
        fileprivate(set) var emojify: Bool = false
        fileprivate(set) var isSourceTextExpanded: Bool = false
        fileprivate(set) var style: TelegramComposeAIMessageMode.StyleReference = .neutral
        var displayStyleTooltip: Bool = false
        
        fileprivate(set) var isProcessing: Bool = false {
            didSet {
                if self.isProcessing != oldValue {
                    self.isProcessingUpdated?(self.isProcessing)
                }
            }
        }
        var isProcessingUpdated: ((Bool) -> Void)?
        
        fileprivate(set) var nonPremiumFloodTriggered: Bool = false {
            didSet {
                if self.nonPremiumFloodTriggered != oldValue {
                    self.nonPremiumFloodTriggeredUpdated?(self.nonPremiumFloodTriggered)
                }
            }
        }
        var nonPremiumFloodTriggeredUpdated: ((Bool) -> Void)?
        
        init() {
        }
    }

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let styles: [TextProcessingScreen.Style]
    let inputText: ComposedRichMessage
    let externalState: ExternalState
    let mode: Mode
    let appliedPrompt: String?
    let copyAction: (() -> Void)?
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool,  @escaping (String, TelegramComposeAIMessageMode.StyleReference) -> Void) -> Void
    let createStyle: () -> Void
    let openStyleContextMenu: (TelegramComposeAIMessageMode.StyleReference, ContextGesture, ContextExtractedContentContainingView) -> Void
    let present: (ViewController, Any?) -> Void
    let rootViewForTextSelection: () -> UIView?
    let openPeer: (EnginePeer) -> Void
    let requestAnotherPreviewExample: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        styles: [TextProcessingScreen.Style],
        externalState: ExternalState,
        inputText: ComposedRichMessage,
        mode: Mode,
        appliedPrompt: String?,
        copyAction: (() -> Void)?,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool, @escaping (String, TelegramComposeAIMessageMode.StyleReference) -> Void) -> Void,
        createStyle: @escaping () -> Void,
        openStyleContextMenu: @escaping (TelegramComposeAIMessageMode.StyleReference, ContextGesture, ContextExtractedContentContainingView) -> Void,
        present: @escaping (ViewController, Any?) -> Void,
        rootViewForTextSelection: @escaping () -> UIView?,
        openPeer: @escaping (EnginePeer) -> Void,
        requestAnotherPreviewExample: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.styles = styles
        self.externalState = externalState
        self.inputText = inputText
        self.mode = mode
        self.appliedPrompt = appliedPrompt
        self.copyAction = copyAction
        self.displayLanguageSelectionMenu = displayLanguageSelectionMenu
        self.createStyle = createStyle
        self.openStyleContextMenu = openStyleContextMenu
        self.present = present
        self.rootViewForTextSelection = rootViewForTextSelection
        self.openPeer = openPeer
        self.requestAnotherPreviewExample = requestAnotherPreviewExample
    }

    static func ==(lhs: TextProcessingTranslateContentComponent, rhs: TextProcessingTranslateContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.styles != rhs.styles {
            return false
        }
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.inputText != rhs.inputText {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.appliedPrompt != rhs.appliedPrompt {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sourceText = ComponentView<Empty>()
        private let styleSelection = ComponentView<Empty>()
        private let styleSelectionContainer: UIView
        private let targetText = ComponentView<Empty>()
        private var promptSeparatorLayer: SimpleLayer?
        private var promptField: ComponentView<Empty>?
        private var promptFieldState = TextFieldComponent.ExternalState()
        private let separatorLayer: SimpleLayer
        
        private var styleTooltip: (dimView: UIView, tooltip: ComponentView<Empty>)?
        
        private var component: TextProcessingTranslateContentComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var processDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.styleSelectionContainer = SparseContainerView()
            self.styleSelectionContainer.clipsToBounds = true
            self.styleSelectionContainer.layer.cornerRadius = 26.0
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.processDisposable?.dispose()
        }
        
        private func beginTranslationIfNecessary(reset: Bool, force: Bool) {
            guard let component = self.component else {
                return
            }
            
            if reset {
                self.processDisposable?.dispose()
                self.processDisposable = nil
                if let result = component.externalState.result {
                    component.externalState.result = (result.language, nil, [])
                }
            }
            
            if let result = component.externalState.result, (result.text == nil || force), self.processDisposable == nil {
                let mappedMode: TelegramComposeAIMessageMode?
                
                switch component.mode {
                case .translate:
                    mappedMode = .translate(toLanguage: result.language, emojify: component.externalState.emojify, style: component.externalState.style)
                case .stylize:
                    if case let .stylize(isComposeWithAI) = component.mode, isComposeWithAI {
                        if let appliedPrompt = component.appliedPrompt, !appliedPrompt.isEmpty {
                            mappedMode = .generate(prompt: appliedPrompt)
                            component.externalState.isProcessing = true
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        } else {
                            mappedMode = nil
                        }
                    } else if case .prompt = component.externalState.style {
                        if let appliedPrompt = component.appliedPrompt, !appliedPrompt.isEmpty {
                            mappedMode = .stylize(emojify: component.externalState.emojify, style: .prompt(appliedPrompt))
                            component.externalState.isProcessing = true
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        } else {
                            mappedMode = nil
                        }
                    } else if !component.externalState.emojify && component.externalState.style == .neutral {
                        mappedMode = nil
                        component.externalState.isProcessing = false
                        component.externalState.result = (result.language, component.inputText, [])
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    } else {
                        mappedMode = .stylize(emojify: component.externalState.emojify, style: component.externalState.style)
                    }
                case .preview:
                    mappedMode = nil
                case .fix:
                    mappedMode = .proofread
                }
                
                if let mappedMode {
                    component.externalState.isProcessing = true
                    self.processDisposable = (component.context.engine.messages.composeAIMessage(
                        text: component.inputText,
                        mode: mappedMode
                    ) |> deliverOnMainQueue).startStrict(next: { [weak self] processedText in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.externalState.isProcessing = false
                        component.externalState.result = (result.language, processedText.text, processedText.diffRanges)
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }, error: { [weak self] error in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.externalState.isProcessing = false
                        if case .nonPremiumFlood = error {
                            component.externalState.nonPremiumFloodTriggered = true
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    })
                }
            }
        }
        
        func scrollStylesToStart() {
            if let styleSelectionView = self.styleSelection.view as? TextProcessingStyleSelectionComponent.View {
                styleSelectionView.scrollToStart()
            }
        }
        
        func refreshResult() {
            if let processDisposable = self.processDisposable {
                self.processDisposable = nil
                processDisposable.dispose()
            }
            self.beginTranslationIfNecessary(reset: false, force: true)
        }

        func update(component: TextProcessingTranslateContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            let previousComponent = self.component
            
            if component.externalState.sourceLanguage == nil {
                let plainText: String
                switch component.inputText {
                case .empty:
                    plainText = ""
                case let .plain(text, _):
                    plainText = text
                case let .rich(instantPage):
                    plainText = instantPage.plainText
                }

                languageRecognizer.processString(plainText)
                let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
                languageRecognizer.reset()
                        
                let filteredLanguages = hypotheses.sorted(by: { $0.value > $1.value })
                if let first = filteredLanguages.first {
                    component.externalState.sourceLanguage = normalizeTranslationLanguage(first.key.rawValue)
                } else {
                    component.externalState.sourceLanguage = "en"
                }
            }
            
            self.component = component
            self.state = state
            
            if component.externalState.result == nil {
                switch component.mode {
                case let .translate(ignoredLanguages):
                    var baseLang = component.strings.baseLanguageCode
                    let rawSuffix = "-raw"
                    if baseLang.hasSuffix(rawSuffix) {
                        baseLang = String(baseLang.dropLast(rawSuffix.count))
                    }
                    var toLanguage = baseLang
                    
                    let fromLanguage = component.externalState.sourceLanguage ?? ""
                    if toLanguage == fromLanguage {
                        if fromLanguage == "en" {
                            var dontTranslateLanguages = Set<String>()
                            if !ignoredLanguages.isEmpty {
                                dontTranslateLanguages = Set(ignoredLanguages)
                            } else {
                                dontTranslateLanguages.insert(baseLang)
                                for language in systemLanguageCodes() {
                                    dontTranslateLanguages.insert(language)
                                }
                            }
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
                    
                    component.externalState.result = (toLanguage, nil, [])
                    self.beginTranslationIfNecessary(reset: false, force: false)
                case let .stylize(isComposeWithAI):
                    if isComposeWithAI {
                        component.externalState.result = ("", nil, [])
                    } else {
                        component.externalState.result = ("", component.inputText, [])
                    }
                case .fix:
                    component.externalState.result = ("", nil, [])
                    self.beginTranslationIfNecessary(reset: false, force: false)
                case .preview:
                    component.externalState.result = ("", component.inputText, [])
                }
            }
            if case let .stylize(isComposeWithAI) = component.mode, let appliedPrompt = component.appliedPrompt, !appliedPrompt.isEmpty {
                var beginGenerating = false
                
                var isCompose = false
                if isComposeWithAI {
                    isCompose = true
                } else if case .prompt = component.externalState.style {
                    isCompose = true
                }
                
                if isCompose {
                    if let previousComponent {
                        if previousComponent.appliedPrompt != appliedPrompt {
                            beginGenerating = true
                        }
                    } else {
                        beginGenerating = true
                    }
                    if beginGenerating {
                        self.beginTranslationIfNecessary(reset: false, force: false)
                    }
                }
            }
            
            var contentHeight: CGFloat = 0.0
            
            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 17.0
            let bottomInset: CGFloat = 14.0
            let blockSpacing: CGFloat = 30.0
            
            let fromLanguage = component.externalState.sourceLanguage ?? ""
            let fromTitle = localizedLanguageName(strings: component.strings, language: fromLanguage, kind: .translateFrom)
            
            let fromFormat: String
            let toFormat: String
            var toTitle: String
            switch component.mode {
            case .translate:
                fromFormat = component.strings.TextProcessing_Translate_FromLanguage
                toFormat = component.strings.TextProcessing_Translate_ToLanguage
                toTitle = localizedLanguageName(strings: component.strings, language: component.externalState.result?.language ?? "", kind: .translateTo)
                if case .style = component.externalState.style, let styleTitle = component.styles.first(where: { $0.id == component.externalState.style })?.title {
                    toTitle = component.strings.TextProcessing_Translate_LanguageStyle(toTitle, styleTitle).string
                }
            case .stylize, .fix:
                fromFormat = component.strings.TextProcessing_OriginalBadge
                if case let .stylize(isComposeWithAI) = component.mode {
                    if isComposeWithAI {
                        toFormat = component.strings.TextProcessing_ResultBadge
                    } else {
                        if component.externalState.style == .neutral {
                            toFormat = component.strings.TextProcessing_OriginalStyleBadge
                        } else {
                            toFormat = component.strings.TextProcessing_ResultBadge
                        }
                    }
                } else {
                    toFormat = component.strings.TextProcessing_ResultBadge
                }
                toTitle = ""
            case .preview:
                fromFormat = component.strings.TextProcessing_StylePreview_Before
                toFormat = component.strings.TextProcessing_StylePreview_After
                toTitle = ""
            }
            
            var fromText: ComposedRichMessage? = component.inputText
            var fromTextMeasurementString: ComposedRichMessage?
            var toTextMeasurementString: ComposedRichMessage?
            var toText: ComposedRichMessage? = component.externalState.result?.text
            var isPreview = false
            if case let .preview(from, to, _, _, isRequesting) = component.mode {
                isPreview = true
                if isRequesting {
                    fromText = nil
                    toText = nil
                } else {
                    fromText = from
                    toText = to
                }
                fromTextMeasurementString = from
                toTextMeasurementString = to
            } else if case let .stylize(isComposeWithAI) = component.mode, !isComposeWithAI, component.appliedPrompt == nil {
                toText = component.externalState.result?.text ?? component.inputText
            }
            
            if case let .stylize(isComposeWithAI) = component.mode, !isComposeWithAI {
                if case .style = component.externalState.style, let style = component.styles.first(where: { $0.id == component.externalState.style }), let authorPeer = style.authorPeer {
                    let footerText: String
                    if let addressName = authorPeer.addressName {
                        footerText = component.strings.TextProcessing_StyleFooterAuthor("@" + addressName).string
                    } else {
                        footerText = component.strings.TextProcessing_StyleFooterAuthor(authorPeer.displayTitle(strings: component.strings, displayOrder: .firstLast)).string
                    }
                    component.externalState.sectionFooter = AnyComponentWithIdentity(id: "style_by_\(authorPeer.id.toInt64())", component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: footerText, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.freeTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.list.freeTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )),
                        highlightColor: component.theme.list.itemAccentColor.withAlphaComponent(0.1),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                return NSAttributedString.Key(rawValue: "URL")
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] as? String {
                                component.openPeer(authorPeer)
                            }
                        }
                    )))
                } else {
                    component.externalState.sectionFooter = nil
                }
            } else if case let .preview(_, _, authorPeer, userCount, _) = component.mode {
                component.externalState.sectionHeader = AnyComponentWithIdentity(id: "preview", component: AnyComponent(HStack([
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: component.strings.TextProcessing_StylePreview_ExampleHeader, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.freeTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.list.freeTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        ))
                    ))),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                                name: "Settings/Refresh",
                                tintColor: component.theme.list.itemAccentColor
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: component.strings.TextProcessing_StylePreview_ExampleHeaderRefresh, font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor))
                            )))
                        ], spacing: 2.0)),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.requestAnotherPreviewExample()
                        },
                        animateScale: false,
                        animateContents: false
                    ))),
                ], spacing: 8.0, alignment: .alternatingLeftRight)))
                
                let userCountString = component.strings.TextProcessing_StyleFooterUserCount(Int32(userCount))
                
                let footerText: String
                if let authorPeer {
                    if let addressName = authorPeer.addressName {
                        footerText = component.strings.TextProcessing_StyleFooterCreatedByFormat(userCountString, component.strings.TextProcessing_StyleFooterCreatedBy("@" + addressName).string).string
                    } else {
                        footerText = component.strings.TextProcessing_StyleFooterCreatedByFormat(userCountString, component.strings.TextProcessing_StyleFooterCreatedBy(authorPeer.displayTitle(strings: component.strings, displayOrder: .firstLast)).string).string
                    }
                } else {
                    footerText = component.strings.TextProcessing_StyleFooterCreatedBySimpleFormat(userCountString).string
                }
                component.externalState.sectionFooter = AnyComponentWithIdentity(id: "style_by_\(authorPeer?.id.toInt64() ?? 0)", component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: footerText, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.freeTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: component.theme.list.freeTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    )),
                    highlightColor: component.theme.list.itemAccentColor.withAlphaComponent(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] attributes, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let authorPeer, let _ = attributes[NSAttributedString.Key(rawValue: "URL")] as? String {
                            component.openPeer(authorPeer)
                        }
                    }
                )))
            }
            
            if case let .stylize(isComposeWithAI) = component.mode {
                let styleSelectionSize = self.styleSelection.update(
                    transition: transition,
                    component: AnyComponent(TextProcessingStyleSelectionComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        styles: component.styles,
                        selectedStyle: component.externalState.style.id,
                        updateStyle: { [weak self] style in
                            guard let self, let component = self.component else {
                                return
                            }
                            if component.externalState.style != style {
                                component.externalState.style = style
                                
                                if let result = component.externalState.result {
                                    component.externalState.result = (result.language, nil, [])
                                    self.beginTranslationIfNecessary(reset: true, force: false)
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    }
                                }
                            }
                        },
                        createStyle: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.createStyle()
                        },
                        openStyleContextMenu: { [weak self] styleId, gesture, sourceView in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.openStyleContextMenu(styleId, gesture, sourceView)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 46.0)
                )
                var styleSelectionFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + contentHeight), size: styleSelectionSize)
                
                let displayStyleSelection = !isComposeWithAI
                if displayStyleSelection {
                    contentHeight += topInset + styleSelectionSize.height
                } else {
                    styleSelectionFrame.origin.y -= styleSelectionSize.height
                }
                
                if let styleSelectionView = self.styleSelection.view {
                    if styleSelectionView.superview == nil {
                        self.styleSelection.parentState = state
                        self.styleSelectionContainer.addSubview(styleSelectionView)
                        self.addSubview(self.styleSelectionContainer)
                    }
                    transition.setFrame(view: styleSelectionView, frame: styleSelectionFrame)
                    transition.setAlpha(view: styleSelectionView, alpha: displayStyleSelection ? 1.0 : 0.0)
                }
            } else {
                contentHeight += topInset
                let sourceTextSize = self.sourceText.update(
                    transition: transition,
                    component: AnyComponent(TextProcessingTextAreaComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        titleFormat: fromFormat,
                        title: fromTitle,
                        titleAction: nil,
                        isExpanded: isPreview ? nil : (
                            component.externalState.isSourceTextExpanded,
                            { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.externalState.isSourceTextExpanded = !component.externalState.isSourceTextExpanded
                                if !self.isUpdating {
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                            }
                        ),
                        copyAction: nil,
                        emojify: nil,
                        text: fromText,
                        loadingStateMeasuringText: fromTextMeasurementString,
                        textCorrectionRanges: [],
                        present: component.present,
                        rootViewForTextSelection: component.rootViewForTextSelection
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                
                let sourceTextFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: sourceTextSize)
                contentHeight += sourceTextSize.height
                
                if let sourceTextView = self.sourceText.view {
                    if sourceTextView.superview == nil {
                        self.sourceText.parentState = state
                        self.addSubview(sourceTextView)
                    }
                    transition.setFrame(view: sourceTextView, frame: sourceTextFrame)
                }
            }
            
            let isTranslate: Bool
            if case .translate = component.mode {
                isTranslate = true
            } else {
                isTranslate = false
            }
            
            var displayEmojify = false
            if isTranslate {
                displayEmojify = true
            } else if case let .stylize(isComposeWithAI) = component.mode, !isComposeWithAI {
                displayEmojify = true
            }
            
            let targetTextSize = self.targetText.update(
                transition: transition,
                component: AnyComponent(TextProcessingTextAreaComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    titleFormat: toFormat,
                    title: toTitle,
                    titleAction: isTranslate ? { [weak self] sourceView in
                        guard let self, let component = self.component, let result = component.externalState.result else {
                            return
                        }
                        component.displayLanguageSelectionMenu(sourceView, result.language, component.externalState.style.id, true, { [weak self] language, style in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            if component.externalState.result?.language != language || component.externalState.style != style {
                                component.externalState.result = (language, nil, [])
                                component.externalState.style = style
                                
                                if !self.isUpdating {
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                                self.beginTranslationIfNecessary(reset: true, force: false)
                            }
                        })
                    } : nil,
                    isExpanded: nil,
                    copyAction: component.copyAction != nil ? { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.copyAction?()
                    } : nil,
                    emojify: displayEmojify ? (
                        component.externalState.emojify,
                        { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.externalState.emojify = !component.externalState.emojify
                            
                            self.beginTranslationIfNecessary(reset: true, force: false)
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    ) : nil,
                    text: toText,
                    loadingStateMeasuringText: toTextMeasurementString ?? component.inputText,
                    textCorrectionRanges: component.mode == .fix ? (component.externalState.result?.textCorrectionRanges ?? []) : [],
                    present: component.present,
                    rootViewForTextSelection: component.rootViewForTextSelection
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            var displayTargetText = true
            if case let .stylize(isComposeWithAI) = component.mode {
                if !(!isComposeWithAI || component.appliedPrompt != nil) {
                    displayTargetText = false
                }
            }
            
            var displayComposePrompt = false
            if case let .stylize(isComposeWithAI) = component.mode {
                if isComposeWithAI {
                    displayComposePrompt = true
                } else {
                    if case .prompt = component.externalState.style {
                        displayComposePrompt = true
                    }
                }
            }
            if displayComposePrompt {
                let promptField: ComponentView<Empty>
                var promptFieldTransition = transition
                if let current = self.promptField {
                    promptField = current
                } else{
                    promptField = ComponentView()
                    self.promptField = promptField
                    promptFieldTransition = promptFieldTransition.withAnimation(.none)
                }
                
                if case let .stylize(isComposeWithAI) = component.mode, !isComposeWithAI {
                    contentHeight += 15.0
                    let promptSeparatorLayer: SimpleLayer
                    if let current = self.promptSeparatorLayer {
                        promptSeparatorLayer = current
                    } else {
                        promptSeparatorLayer = SimpleLayer()
                        self.promptSeparatorLayer = promptSeparatorLayer
                        promptSeparatorLayer.opacity = 0.0
                        self.layer.addSublayer(promptSeparatorLayer)
                    }
                    
                    promptFieldTransition.setFrame(layer: promptSeparatorLayer, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 1.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
                    promptSeparatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
                    transition.setAlpha(layer: promptSeparatorLayer, alpha: displayTargetText ? 1.0 : 0.0)
                }
                
                let promptFieldSize = promptField.update(
                    transition: promptFieldTransition,
                    component: AnyComponent(TextFieldComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        externalState: self.promptFieldState,
                        fontSize: 17.0,
                        textColor: component.theme.list.itemPrimaryTextColor,
                        accentColor: component.theme.list.itemAccentColor,
                        insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0),
                        hideKeyboard: false,
                        customInputView: nil,
                        placeholder: NSAttributedString(string: component.strings.TextProcessing_PromptPlaceholder, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor),
                        placeholderVerticalOffset: 3.0,
                        resetText: nil,
                        isOneLineWhenUnfocused: false,
                        characterLimit: 1000,
                        enableInlineAnimations: true,
                        emptyLineHandling: .allowed,
                        formatMenuAvailability: .none,
                        lockedFormatAction: {},
                        present: { _ in },
                        paste: { _ in },
                        returnKeyAction: {
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let promptFieldFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: promptFieldSize)
                if let promptFieldView = promptField.view {
                    promptField.parentState = state
                    if promptFieldView.superview == nil {
                        promptFieldView.alpha = 0.0
                        self.addSubview(promptFieldView)
                        self.promptFieldState.updated = { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.externalState.promptText = self.promptFieldState.text.string
                            component.externalState.promptTextUpdated?()
                        }
                    }
                    promptFieldTransition.setFrame(view: promptFieldView, frame: promptFieldFrame)
                    transition.setAlpha(view: promptFieldView, alpha: 1.0)
                }
                contentHeight += promptFieldSize.height + 2.0
                if displayTargetText {
                    contentHeight -= 14.0
                }
            } else {
                if let promptField = self.promptField {
                    self.promptField = nil
                    self.promptFieldState = TextFieldComponent.ExternalState()
                    if let promptFieldView = promptField.view {
                        transition.setAlpha(view: promptFieldView, alpha: 0.0, completion: { [weak promptFieldView] _ in
                            promptFieldView?.removeFromSuperview()
                        })
                    }
                }
                if let promptSeparatorLayer = self.promptSeparatorLayer {
                    self.promptSeparatorLayer = nil
                    transition.setAlpha(layer: promptSeparatorLayer, alpha: 0.0, completion: { [weak promptSeparatorLayer] _ in
                        promptSeparatorLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight + floorToScreenPixels((blockSpacing - UIScreenPixel) * 0.5) - 1.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
            self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            transition.setAlpha(layer: self.separatorLayer, alpha: displayTargetText ? 1.0 : 0.0)
            
            let targetTextFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + blockSpacing), size: targetTextSize)
            if displayTargetText {
                contentHeight += blockSpacing
                contentHeight += targetTextSize.height
            }
            
            var targetTextAlpha: CGFloat = 1.0
            if displayComposePrompt && component.externalState.isProcessing {
                targetTextAlpha = 0.5
            }
            
            if let targetTextView = self.targetText.view {
                if targetTextView.superview == nil {
                    self.targetText.parentState = state
                    targetTextView.layer.allowsGroupOpacity = true
                    self.addSubview(targetTextView)
                }
                transition.setFrame(view: targetTextView, frame: targetTextFrame)
                transition.setAlpha(view: targetTextView, alpha: displayTargetText ? targetTextAlpha : 0.0)
            }

            if displayTargetText {
                contentHeight += bottomInset
            }
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            
            if component.externalState.displayStyleTooltip, let sourceTextView = self.sourceText.view {
                let tooltip: ComponentView<Empty>
                let dimView: UIView
                var tooltipTransition = transition
                if let current = self.styleTooltip {
                    tooltip = current.tooltip
                    dimView = current.dimView
                } else {
                    tooltipTransition = tooltipTransition.withAnimation(.none)
                    tooltip = ComponentView()
                    let dimViewValue = TransparentHitView()
                    dimViewValue.onTap = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.externalState.displayStyleTooltip = false
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                    }
                    dimView = dimViewValue
                    self.styleTooltip = (dimView, tooltip)
                }
                let tooltipSize = tooltip.update(
                    transition: tooltipTransition,
                    component: AnyComponent(TooltipComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.strings.TextProcessing_StyleTooltip, font: Font.regular(15.0), textColor: .white))
                        ))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
                transition.setFrame(view: dimView, frame: CGRect(origin: CGPoint(), size: size))
                let tooltipFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - tooltipSize.width) * 0.5), y: sourceTextView.frame.maxY + 12.0), size: tooltipSize)
                if let tooltipView = tooltip.view as? TooltipComponent.View {
                    if tooltipView.superview == nil {
                        self.addSubview(dimView)
                        self.addSubview(tooltipView)
                    }
                    tooltipTransition.setFrame(view: tooltipView, frame: tooltipFrame)
                    tooltipView.updateBackground(relativeArrowTargetPosition: CGPoint(x: tooltipFrame.width * 0.5, y: 0.0))
                }
            } else {
                if let styleTooltip = self.styleTooltip {
                    self.styleTooltip = nil
                    styleTooltip.dimView.removeFromSuperview()
                    if let tooltipView = styleTooltip.tooltip.view {
                        transition.setAlpha(view: tooltipView, alpha: 0.0, completion: { [weak tooltipView] _ in
                            tooltipView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            transition.setFrame(view: self.styleSelectionContainer, frame: CGRect(origin: CGPoint(), size: size))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
