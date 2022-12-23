import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import Speak
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import UndoUI

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

private final class TranslateScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let text: String
    let fromLanguage: String?
    let toLanguage: String
    let copyTranslation: (String) -> Void
    let changeLanguage: (String, String, @escaping (String, String) -> Void) -> Void
    let expand: () -> Void
    
    init(context: AccountContext, text: String, fromLanguage: String?, toLanguage: String, copyTranslation: @escaping (String) -> Void, changeLanguage: @escaping (String, String, @escaping (String, String) -> Void) -> Void, expand: @escaping () -> Void) {
        self.context = context
        self.text = text
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.copyTranslation = copyTranslation
        self.changeLanguage = changeLanguage
        self.expand = expand
    }
    
    static func ==(lhs: TranslateScreenComponent, rhs: TranslateScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
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
        var textExpanded: Bool = false
        
        var toLanguage: String
        var translatedText: String?
        
        private let expand: () -> Void
        
        private var translationDisposable = MetaDisposable()
        
        fileprivate var isSpeakingOriginalText: Bool = false
        fileprivate var isSpeakingTranslatedText: Bool = false
        private var speechHolder: SpeechSynthesizerHolder?
        fileprivate var availableSpeakLanguages: Set<String>
        
        fileprivate var moreBackgroundImage: (CGSize, UIImage, UIColor)?
        
        init(context: AccountContext, fromLanguage: String?, text: String, toLanguage: String, expand: @escaping () -> Void) {
            self.context = context
            self.text = text
            self.fromLanguage = fromLanguage
            self.toLanguage = toLanguage
            self.expand = expand
            self.availableSpeakLanguages = supportedSpeakLanguages()
            
            super.init()
                        
            self.translationDisposable.set((context.engine.messages.translate(text: text, fromLang: fromLanguage, toLang: toLanguage) |> deliverOnMainQueue).start(next: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.translatedText = text
//                if strongSelf.fromLanguage == nil {
//                    strongSelf.fromLanguage = result.detectedLanguage
//                }
                strongSelf.updated(transition: .immediate)
            }, error: { error in
                
            }))
        }
        
        deinit {
            self.speechHolder?.stop()
            self.translationDisposable.dispose()
        }
        
        func changeLanguage(fromLanguage: String, toLanguage: String) {
            guard self.fromLanguage != fromLanguage || self.toLanguage != toLanguage else {
                return
            }
            self.fromLanguage = fromLanguage
            self.toLanguage = toLanguage
            self.translatedText = nil
            self.updated(transition: .immediate)
            
            self.translationDisposable.set((self.context.engine.messages.translate(text: text, fromLang: fromLanguage, toLang: toLanguage) |> deliverOnMainQueue).start(next: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.translatedText = text
//                if strongSelf.fromLanguage == nil {
//                    strongSelf.fromLanguage = result.detectedLanguage
//                }
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
                self.speechHolder = speakText(context: self.context, text: translatedText)
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
    }
    
    func makeState() -> State {
        return State(context: self.context, fromLanguage: self.fromLanguage, text: self.text, toLanguage: self.toLanguage, expand: self.expand)
    }
    
    static var body: Body {
        let textBackground = Child(RoundedRectangle.self)
        
        let originalTitle = Child(MultilineTextComponent.self)
        let originalText = Child(MultilineTextComponent.self)
        
        let originalMoreBackground = Child(Image.self)
        let originalMoreButton = Child(Button.self)
        
        let originalSpeakButton = Child(Button.self)
        
        let translationTitle = Child(MultilineTextComponent.self)
        let translationText = Child(MultilineTextComponent.self)
        let translationPlaceholder = Child(RoundedRectangle.self)
        let translationSpeakButton = Child(Button.self)
        
        let copyButton = Child(TranslateButtonComponent.self)
        let changeLanguageButton = Child(TranslateButtonComponent.self)
        
        let textStripe = Child(Rectangle.self)

        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let theme = environment.theme
            let strings = environment.strings
            
            let topInset: CGFloat = environment.navigationHeight + 22.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textTopInset: CGFloat = 16.0
            let textSideInset: CGFloat = 16.0
            let textSpacing: CGFloat = 5.0
            let itemSpacing: CGFloat = 16.0
            let itemHeight: CGFloat = 44.0
            
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
            let originalTitle = originalTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: fromLanguage, font: Font.medium(13.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .natural)),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
                        
            let originalText = originalText.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: state.text, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .natural)),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: state.textExpanded ? 0 : 1,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0 - (state.textExpanded ? 30.0 : 0.0), height: context.availableSize.height),
                transition: .immediate
            )
            
            let toLanguage = locale.localizedString(forLanguageCode: state.toLanguage) ?? ""
            let translationTitle = translationTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: toLanguage, font: Font.medium(13.0), textColor: theme.list.itemAccentColor, paragraphAlignment: .natural)),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let translationTextHeight: CGFloat
            
            var maybeTranslationText: _UpdatedChildComponent? = nil
            var maybeTranslationPlaceholder: _UpdatedChildComponent? = nil
            if let translatedText = state.translatedText {
                maybeTranslationText = translationText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: translatedText, font: Font.medium(17.0), textColor: theme.list.itemAccentColor, paragraphAlignment: .natural)),
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
            
            let textBackgroundOrigin = CGPoint(x: sideInset, y: topInset)
                
            let textStripe = textStripe.update(
                component: Rectangle(color: theme.list.itemPlainSeparatorColor),
                availableSize: CGSize(width: context.availableSize.width - (sideInset + textSideInset) * 2.0, height: UIScreenPixel),
                transition: .immediate
            )
            
            let textBackgroundSize = CGSize(width: context.availableSize.width - sideInset * 2.0, height: textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight + itemSpacing)
            
            let textBackground = textBackground.update(
                component: RoundedRectangle(color: theme.list.itemBlocksBackgroundColor, cornerRadius: 10.0),
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
                                    size: CGSize(width: 22.0, height: 22.0)
                                ))),
                                AnyComponentWithIdentity(id: "a", component: AnyComponent(PlayPauseIconComponent(
                                    state: state.isSpeakingOriginalText ? .pause : .play,
                                    tintColor: checkColor,
                                    size: CGSize(width: 18.0, height: 18.0)
                                ))),
                            ])),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                state.speakOriginalText()
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: CGSize(width: 22.0, height: 22.0),
                        transition: .immediate
                    )
                    
                    context.add(originalSpeakButton
                        .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalSpeakButton.size.width / 2.0 - 3.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height - originalSpeakButton.size.height / 2.0 - 2.0))
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
                    .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalMoreBackground.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalMoreBackground.size.height / 2.0 - 1.0))
                )
                
                context.add(originalMoreButton
                    .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - originalMoreButton.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height / 2.0 - 1.0))
                )
            }
            
            context.add(translationTitle
                .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationTitle.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height / 2.0))
            )
            
            if let translationText = maybeTranslationText {
                context.add(translationText
                    .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationText.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationText.size.height / 2.0))
                )
            } else if let translationPlaceholder = maybeTranslationPlaceholder {
                context.add(translationPlaceholder
                    .position(CGPoint(x: textBackgroundOrigin.x + textSideInset + translationPlaceholder.size.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationPlaceholder.size.height / 2.0 + 4.0))
                )
            }
            
            if state.availableSpeakLanguages.contains(state.toLanguage) {
                let translationSpeakButton = translationSpeakButton.update(
                    component: Button(
                        content: AnyComponent(ZStack([
                            AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                                fillColor: theme.list.itemAccentColor,
                                size: CGSize(width: 22.0, height: 22.0)
                            ))),
                            AnyComponentWithIdentity(id: "a", component: AnyComponent(PlayPauseIconComponent(
                                state: state.isSpeakingTranslatedText ? .pause : .play,
                                tintColor: theme.list.itemCheckColors.foregroundColor,
                                size: CGSize(width: 18.0, height: 18.0)
                            ))),
                        ])),
                        action: { [weak state] in
                            guard let state = state else {
                                return
                            }
                            state.speakTranslatedText()
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)),
                    availableSize: CGSize(width: 22.0, height: 22.0),
                    transition: .immediate
                )
                                
                context.add(translationSpeakButton
                    .position(CGPoint(x: context.availableSize.width - sideInset - textSideInset - translationSpeakButton.size.width / 2.0 - 3.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight - translationSpeakButton.size.height / 2.0 - 2.0))
                )
            }
            
            let component = context.component
            let copyButton = copyButton.update(
                component: TranslateButtonComponent(
                    theme: theme,
                    title: strings.Translate_CopyTranslation,
                    icon: "Chat/Context Menu/Copy",
                    isEnabled: state.translatedText != nil,
                    action: { [weak component] in
                        component?.copyTranslation(state.translatedText ?? "")
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: itemHeight),
                transition: context.transition
            )
            
            let changeLanguageButton = changeLanguageButton.update(
                component: TranslateButtonComponent(
                    theme: theme,
                    title: strings.Translate_ChangeLanguage,
                    icon: "Chat/Context Menu/Translate",
                    isEnabled: true,
                    action: { [weak component] in
                        component?.changeLanguage(state.fromLanguage ?? "", state.toLanguage, { fromLang, toLang in
                            state.changeLanguage(fromLanguage: fromLang, toLanguage: toLang)
                        })
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: itemHeight),
                transition: context.transition
            )
            
            let buttonsSpacing: CGFloat = 24.0
            let smallSectionSpacing: CGFloat = 8.0
            
            context.add(copyButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight + itemSpacing + buttonsSpacing + copyButton.size.height / 2.0))
            )
            
            context.add(changeLanguageButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight + itemSpacing + buttonsSpacing + copyButton.size.height + smallSectionSpacing + changeLanguageButton.size.height / 2.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: textBackgroundOrigin.y + textTopInset + originalTitle.size.height + textSpacing + originalText.size.height + itemSpacing + textTopInset + translationTitle.size.height + textSpacing + translationTextHeight + itemSpacing + buttonsSpacing + copyButton.size.height + smallSectionSpacing + changeLanguageButton.size.height + environment.safeInsets.bottom + 44.0)
            
            return contentSize
        }
    }
}

public class TranslateScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: TranslateScreen?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let theme: PresentationTheme?
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let scrollView: UIScrollView
        let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
        init(context: AccountContext, controller: TranslateScreen, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: PresentationTheme?) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.scrollView = UIScrollView()
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.scrollView.delegate = self
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.scrollView)
            self.scrollView.addSubview(self.hostView)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = self.scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            if !self.temporaryDismiss {
                self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
            }
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            if let controller = self.controller, let navigationBar = controller.navigationBar, navigationBar.view.superview !== self.wrappingView {
                self.containerView.addSubview(navigationBar.view)
            }
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
                
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: clipFrame.size), completion: nil)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                isVisible: self.currentIsVisible,
                theme: self.theme ?? self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            var contentSize = self.hostView.update(
                transition: transition,
                component: self.component,
                environment: {
                    environment
                },
                forceUpdate: true,
                containerSize: CGSize(width: clipFrame.size.width, height: 10000.0)
            )
            contentSize.height = max(layout.size.height - navigationHeight, contentSize.height)
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let (layout, _) = self.currentLayout else{
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                var factor: CGFloat = 0.2488
                if layout.size.width <= 320.0 {
                    factor = 0.15
                }
                return floor(max(layout.size.width, layout.size.height) * factor)
            } else {
                return 210.0
            }
        }
        
        private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.isExpanded = isExpanded
            
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme?
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    private var isInitiallyExpanded = false
    
    private var currentLayout: ContainerViewLayout?
    
    public var pushController: (ViewController) -> Void = { _ in }
    public var presentController: (ViewController) -> Void = { _ in }
    
    public convenience init(context: AccountContext, text: String, fromLanguage: String?, toLanguage: String? = nil, isExpanded: Bool = false) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var baseLanguageCode = presentationData.strings.baseLanguageCode
        let rawSuffix = "-raw"
        if baseLanguageCode.hasSuffix(rawSuffix) {
            baseLanguageCode = String(baseLanguageCode.dropLast(rawSuffix.count))
        }
        
        var toLanguage = toLanguage ?? baseLanguageCode
        
        if toLanguage == fromLanguage {
            toLanguage = "en"
        }
        
        var copyTranslationImpl: ((String) -> Void)?
        var changeLanguageImpl: ((String, String, @escaping (String, String) -> Void) -> Void)?
        var expandImpl: (() -> Void)?
        self.init(context: context, component: TranslateScreenComponent(context: context, text: text, fromLanguage: fromLanguage, toLanguage: toLanguage, copyTranslation: { text in
            copyTranslationImpl?(text)
        }, changeLanguage: { fromLang, toLang, completion in
            changeLanguageImpl?(fromLang, toLang, completion)
        }, expand: {
            expandImpl?()
        }))
        
        self.isInitiallyExpanded = isExpanded
                
        self.title = presentationData.strings.Translate_Title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        copyTranslationImpl = { [weak self] text in
            UIPasteboard.general.string = text
            let content = UndoOverlayContent.copy(text: presentationData.strings.Conversation_TextCopied)
            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            self?.dismiss(animated: true, completion: nil)
        }
        
        changeLanguageImpl = { [weak self] fromLang, toLang, completion in
            let pushController = self?.pushController
            let presentController = self?.presentController
            let controller = languageSelectionController(context: context, fromLanguage: fromLang, toLanguage: toLang, completion: { fromLang, toLang in
                let controller = TranslateScreen(context: context, text: text, fromLanguage: fromLang, toLanguage: toLang, isExpanded: true)
                controller.pushController = pushController ?? { _ in }
                controller.presentController = presentController ?? { _ in }
                presentController?(controller)
            })
            
            self?.node.temporaryDismiss = true
            self?.dismiss(animated: true, completion: nil)
            
            pushController?(controller)
        }
        
        expandImpl = { [weak self] in
            self?.node.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
            if let currentLayout = self?.currentLayout {
                self?.containerLayoutUpdated(currentLayout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    private init<C: Component>(context: AccountContext, component: C, theme: PresentationTheme? = nil) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = nil
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component, theme: self.theme)
        if self.isInitiallyExpanded {
            (self.displayNode as! Node).update(isExpanded: true, transition: .immediate)
        }
        self.displayNodeDidLoad()
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
    
    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var navigationLayout = self.navigationLayout(layout: layout)
        var navigationFrame = navigationLayout.navigationFrame
        
        var layout = layout
        if case .regular = layout.metrics.widthClass {
            let verticalInset: CGFloat = 44.0
            let maxSide = max(layout.size.width, layout.size.height)
            let minSide = min(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
            let clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            navigationFrame.size.width = clipFrame.width
            layout.size = clipFrame.size
        }
        
        navigationFrame.size.height = 56.0
        navigationLayout.navigationFrame = navigationFrame
        navigationLayout.defaultContentHeight = 56.0
        
        layout.statusBarHeight = nil
        
        self.applyNavigationBarLayout(layout, navigationLayout: navigationLayout, additionalBackgroundHeight: 0.0, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
}
