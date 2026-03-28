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
        case stylize
        case fix
    }
    
    final class ExternalState {
        fileprivate(set) var sourceLanguage: String?
        
        fileprivate(set) var result: (language: String, text: TextWithEntities?, textCorrectionRanges: [Range<Int>])? = nil {
            didSet {
                if self.result?.language != oldValue?.language || self.result?.text != oldValue?.text {
                    self.resultUpdated?(self.result)
                }
            }
        }
        var resultUpdated: (((language: String, text: TextWithEntities?, textCorrectionRanges: [Range<Int>])?) -> Void)?
        
        fileprivate(set) var emojify: Bool = false
        fileprivate(set) var isSourceTextExpanded: Bool = false
        fileprivate(set) var style: TelegramComposeAIMessageMode.StyleId = .neutral
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
    let inputText: TextWithEntities
    let externalState: ExternalState
    let mode: Mode
    let copyAction: (() -> Void)?
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool,  @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void
    let present: (ViewController, Any?) -> Void
    let rootViewForTextSelection: () -> UIView?

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        styles: [TextProcessingScreen.Style],
        externalState: ExternalState,
        inputText: TextWithEntities,
        mode: Mode,
        copyAction: (() -> Void)?,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool, @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void,
        present: @escaping (ViewController, Any?) -> Void,
        rootViewForTextSelection: @escaping () -> UIView?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.styles = styles
        self.externalState = externalState
        self.inputText = inputText
        self.mode = mode
        self.copyAction = copyAction
        self.displayLanguageSelectionMenu = displayLanguageSelectionMenu
        self.present = present
        self.rootViewForTextSelection = rootViewForTextSelection
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
        return true
    }

    final class View: UIView {
        private let sourceText = ComponentView<Empty>()
        private let styleSelection = ComponentView<Empty>()
        private let styleSelectionContainer: UIView
        private let targetText = ComponentView<Empty>()
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
        
        private func beginTranslationIfNecessary(reset: Bool) {
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
            
            if let result = component.externalState.result, result.text == nil, self.processDisposable == nil {
                let mappedMode: TelegramComposeAIMessageMode?
                
                switch component.mode {
                case .translate:
                    mappedMode = .translate(toLanguage: result.language, emojify: component.externalState.emojify, style: component.externalState.style)
                case .stylize:
                    if !component.externalState.emojify && component.externalState.style == .neutral {
                        mappedMode = nil
                        component.externalState.isProcessing = false
                        component.externalState.result = (result.language, component.inputText, [])
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    } else {
                        mappedMode = .stylize(emojify: component.externalState.emojify, style: component.externalState.style)
                    }
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

        func update(component: TextProcessingTranslateContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if component.externalState.sourceLanguage == nil {
                languageRecognizer.processString(component.inputText.text)
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
                    self.beginTranslationIfNecessary(reset: false)
                case .stylize:
                    component.externalState.result = ("", component.inputText, [])
                case .fix:
                    component.externalState.result = ("", nil, [])
                    self.beginTranslationIfNecessary(reset: false)
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
                if case .stylize = component.mode {
                    if component.externalState.style == .neutral {
                        toFormat = component.strings.TextProcessing_OriginalStyleBadge
                    } else {
                        toFormat = component.strings.TextProcessing_ResultBadge
                    }
                } else {
                    toFormat = component.strings.TextProcessing_ResultBadge
                }
                toTitle = ""
            }
            
            contentHeight += topInset
            if case .stylize = component.mode {
                let styleSelectionSize = self.styleSelection.update(
                    transition: transition,
                    component: AnyComponent(TextProcessingStyleSelectionComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        styles: component.styles,
                        selectedStyle: component.externalState.style,
                        updateStyle: { [weak self] style in
                            guard let self, let component = self.component else {
                                return
                            }
                            if component.externalState.style != style {
                                component.externalState.style = style
                                
                                if let result = component.externalState.result {
                                    component.externalState.result = (result.language, nil, [])
                                    self.beginTranslationIfNecessary(reset: true)
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    }
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 46.0)
                )
                let styleSelectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: styleSelectionSize)
                contentHeight += styleSelectionSize.height
                
                if let styleSelectionView = self.styleSelection.view {
                    if styleSelectionView.superview == nil {
                        self.styleSelection.parentState = state
                        self.styleSelectionContainer.addSubview(styleSelectionView)
                        self.addSubview(self.styleSelectionContainer)
                    }
                    transition.setFrame(view: styleSelectionView, frame: styleSelectionFrame)
                }
            } else {
                let sourceTextSize = self.sourceText.update(
                    transition: transition,
                    component: AnyComponent(TextProcessingTextAreaComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        titleFormat: fromFormat,
                        title: fromTitle,
                        titleAction: nil,
                        isExpanded: (
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
                        text: component.inputText,
                        loadingStateMeasuringText: nil,
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
                        component.displayLanguageSelectionMenu(sourceView, result.language, component.externalState.style, true, { [weak self] language, style in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            if component.externalState.result?.language != language || component.externalState.style != style {
                                component.externalState.result = (language, nil, [])
                                component.externalState.style = style
                                
                                if !self.isUpdating {
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                                self.beginTranslationIfNecessary(reset: true)
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
                    emojify: (isTranslate || component.mode == .stylize) ? (
                        component.externalState.emojify,
                        { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.externalState.emojify = !component.externalState.emojify
                            
                            self.beginTranslationIfNecessary(reset: true)
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    ) : nil,
                    text: component.externalState.result?.text,
                    loadingStateMeasuringText: component.inputText.text,
                    textCorrectionRanges: component.mode == .fix ? (component.externalState.result?.textCorrectionRanges ?? []) : [],
                    present: component.present,
                    rootViewForTextSelection: component.rootViewForTextSelection
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight + floorToScreenPixels((blockSpacing - UIScreenPixel) * 0.5) - 1.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
            self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            
            contentHeight += blockSpacing
            let targetTextFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: targetTextSize)
            contentHeight += targetTextSize.height
            
            if let targetTextView = self.targetText.view {
                if targetTextView.superview == nil {
                    self.targetText.parentState = state
                    self.addSubview(targetTextView)
                }
                transition.setFrame(view: targetTextView, frame: targetTextFrame)
            }

            contentHeight += bottomInset
            
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
