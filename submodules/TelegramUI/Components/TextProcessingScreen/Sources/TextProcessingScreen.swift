import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import ButtonComponent
import BundleIconComponent
import TelegramCore
import PresentationDataUtils
import ResizableSheetComponent
import GlassBarButtonComponent
import TabBarComponent
import TranslateUI
import LottieComponent

final class TextProcessingContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class ExternalState {
        fileprivate(set) var isProcessing: Bool = false
        fileprivate(set) var result: TextWithEntities?
        
        init() {
        }
    }

    let externalState: ExternalState
    let context: AccountContext
    let inputText: TextWithEntities
    let copyCurrentResult: () -> Void
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.Style, Bool,  @escaping (String, TelegramComposeAIMessageMode.Style) -> Void) -> Void

    init(
        externalState: ExternalState,
        context: AccountContext,
        inputText: TextWithEntities,
        copyCurrentResult: @escaping () -> Void,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.Style, Bool, @escaping (String, TelegramComposeAIMessageMode.Style) -> Void) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.inputText = inputText
        self.copyCurrentResult = copyCurrentResult
        self.displayLanguageSelectionMenu = displayLanguageSelectionMenu
    }

    static func ==(lhs: TextProcessingContentComponent, rhs: TextProcessingContentComponent) -> Bool {
        return true
    }
    
    private enum Mode {
        case translate
        case stylize
        case fix
    }

    final class View: UIView {
        private var component: TextProcessingContentComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let modeTabs = ComponentView<Empty>()
        
        private let currentContentBackground: UIImageView
        private let currentContentContainer: UIView
        
        private let translateState = TextProcessingTranslateContentComponent.ExternalState()
        private let stylizeState = TextProcessingTranslateContentComponent.ExternalState()
        private let fixState = TextProcessingTranslateContentComponent.ExternalState()
        
        private var currentContent: (mode: Mode, view: ComponentView<Empty>)?
        
        private var currentMode: Mode = .translate
        
        override init(frame: CGRect) {
            self.currentContentBackground = UIImageView()
            self.currentContentContainer = UIView()
            self.currentContentContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.currentContentBackground)
            self.addSubview(self.currentContentContainer)
            
            self.translateState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .translate = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.translateState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .translate = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
            self.stylizeState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .stylize = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.stylizeState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .stylize = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
            self.fixState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .fix = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.fixState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .fix = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: TextProcessingContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0

            var contentHeight: CGFloat = 0.0
            contentHeight += 85.0
            
            var tabs: [TabBarComponent.Item] = []
            tabs.append(TabBarComponent.Item(
                content: .customItem(TabBarComponent.Item.Content.CustomItem(
                    id: "translate",
                    title: "Translate",
                    icon: .bundleIcon(name: "TextProcessing/TabTranslate")
                )),
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if self.currentMode != .translate {
                        self.currentMode = .translate
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                },
                doubleTapAction: nil,
                contextAction: nil
            ))
            tabs.append(TabBarComponent.Item(
                content: .customItem(TabBarComponent.Item.Content.CustomItem(
                    id: "stylize",
                    title: "Style",
                    icon: .bundleIcon(name: "TextProcessing/TabStylize")
                )),
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if self.currentMode != .stylize {
                        self.currentMode = .stylize
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                },
                doubleTapAction: nil,
                contextAction: nil
            ))
            tabs.append(TabBarComponent.Item(
                content: .customItem(TabBarComponent.Item.Content.CustomItem(
                    id: "fix",
                    title: "Fix",
                    icon: .bundleIcon(name: "TextProcessing/TabFix")
                )),
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if self.currentMode != .fix {
                        self.currentMode = .fix
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                },
                doubleTapAction: nil,
                contextAction: nil
            ))
            
            let currentModeId: String
            switch self.currentMode {
            case .translate:
                currentModeId = "translate"
            case .stylize:
                currentModeId = "stylize"
            case .fix:
                currentModeId = "fix"
            }
            let modeTabsSize = self.modeTabs.update(
                transition: transition,
                component: AnyComponent(TabBarComponent(
                    theme: environment.theme,
                    tintSelectedItem: false,
                    strings: environment.strings,
                    items: tabs,
                    search: nil,
                    selectedId: currentModeId,
                    outerInsets: UIEdgeInsets()
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 62.0)
            )
            let modeTabsFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: modeTabsSize)
            if let modeTabsView = self.modeTabs.view {
                if modeTabsView.superview == nil {
                    self.modeTabs.parentState = state
                    self.addSubview(modeTabsView)
                }
                transition.setFrame(view: modeTabsView, frame: modeTabsFrame)
            }
            contentHeight += modeTabsSize.height
            contentHeight += 24.0
            
            if let currentContent = self.currentContent, currentContent.mode != self.currentMode {
                if let currentContentView = currentContent.view.view {
                    transition.setAlpha(view: currentContentView, alpha: 0.0, completion: { [weak currentContentView] _ in
                        currentContentView?.removeFromSuperview()
                    })
                }
                self.currentContent = nil
            }
            
            let contentComponent: AnyComponent<Empty>
            switch self.currentMode {
            case .translate:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    externalState: self.translateState,
                    inputText: component.inputText,
                    mode: .translate,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            case .stylize:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    externalState: self.stylizeState,
                    inputText: component.inputText,
                    mode: .stylize,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            case .fix:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    externalState: self.fixState,
                    inputText: component.inputText,
                    mode: .fix,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            }
            
            let content: ComponentView<Empty>
            var contentTransition = transition
            if let current = self.currentContent {
                content = current.view
            } else {
                content = ComponentView()
                self.currentContent = (self.currentMode, content)
                contentTransition = contentTransition.withAnimation(.none)
            }
            let contentSize = content.update(
                transition: contentTransition,
                component: contentComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000000.0)
            )
            if let contentView = content.view {
                if contentView.superview == nil {
                    content.parentState = state
                    self.currentContentContainer.addSubview(contentView)
                    contentView.layer.allowsGroupOpacity = true
                    contentView.alpha = 0.0
                }
                alphaTransition.setAlpha(view: contentView, alpha: 1.0)
                contentTransition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: contentSize))
            }
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: contentSize)
            transition.setFrame(view: self.currentContentContainer, frame: contentFrame)
            
            if self.currentContentBackground.image == nil {
                self.currentContentBackground.image = generateStretchableFilledCircleImage(diameter: 60.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.currentContentBackground.tintColor = environment.theme.list.itemBlocksBackgroundColor
            transition.setFrame(view: self.currentContentBackground, frame: contentFrame)
            
            contentHeight += contentSize.height
            
            contentHeight += 106.0

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TextProcessingSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let inputText: TextWithEntities
    let copyCurrentResult: (TextWithEntities) -> Void
    let completion: (TextWithEntities) -> Void

    init(
        context: AccountContext,
        inputText: TextWithEntities,
        copyCurrentResult: @escaping (TextWithEntities) -> Void,
        completion: @escaping (TextWithEntities) -> Void
    ) {
        self.context = context
        self.inputText = inputText
        self.copyCurrentResult = copyCurrentResult
        self.completion = completion
    }

    static func ==(lhs: TextProcessingSheetComponent, rhs: TextProcessingSheetComponent) -> Bool {
        return true
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let languageSelectionMenu = Child(TextProcessingLanguageSelectionComponent.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let contentExternalState = TextProcessingContentComponent.ExternalState()
        
        class LanguageSelectionMenuData {
            let sourceView: UIView
            let currentLanguage: String
            let currentStyle: TelegramComposeAIMessageMode.Style
            let displayStyle: Bool
            let completion: (String, TelegramComposeAIMessageMode.Style) -> Void
            
            init(sourceView: UIView, currentLanguage: String, currentStyle: TelegramComposeAIMessageMode.Style, displayStyle: Bool, completion: @escaping (String, TelegramComposeAIMessageMode.Style) -> Void) {
                self.sourceView = sourceView
                self.currentLanguage = currentLanguage
                self.currentStyle = currentStyle
                self.displayStyle = displayStyle
                self.completion = completion
            }
        }
        var languageSelectionMenuData: LanguageSelectionMenuData?

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let theme = environment.theme
            let state = context.state

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

            let completion = context.component.completion
            let performMainAction: () -> Void = {
                if let result = contentExternalState.result {
                    completion(result)
                }
                dismiss(true)
            }
            let copyCurrentResult = context.component.copyCurrentResult
            let copyCurrentResultImpl: () -> Void = {
                if let result = contentExternalState.result {
                    copyCurrentResult(result)
                }
            }

            //TODO:localize (for AI: don't remove this line)
            let titleString: String = "AI Editor"
            //TODO:localize (for AI: don't remove this line)
            let actionButtonTitle: String = "Apply"

            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(TextProcessingContentComponent(
                        externalState: contentExternalState,
                        context: context.component.context,
                        inputText: context.component.inputText,
                        copyCurrentResult: {
                            copyCurrentResultImpl()
                        },
                        displayLanguageSelectionMenu: { [weak state] sourceView, currentLanguage, currentStyle, displayStyle, completion in
                            languageSelectionMenuData = LanguageSelectionMenuData(sourceView: sourceView, currentLanguage: currentLanguage, currentStyle: currentStyle, displayStyle: displayStyle, completion: completion)
                            state?.updated(transition: .immediate)
                        }
                    )),
                    titleItem: AnyComponent(TitleComponent(
                        theme: theme,
                        title: titleString,
                        isProcessing: contentExternalState.isProcessing
                    )),
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
                                component: AnyComponent(ButtonTextContentComponent(
                                    text: actionButtonTitle,
                                    badge: 0,
                                    textColor: theme.list.itemCheckColors.foregroundColor,
                                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                    badgeForeground: theme.list.itemCheckColors.fillColor
                                ))
                            ),
                            isEnabled: !contentExternalState.isProcessing,
                            displaysProgress: false,
                            action: {
                                performMainAction()
                            }
                        )
                    ),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: nil,
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
            
            if let languageSelectionMenuDataValue = languageSelectionMenuData {
                let languageSelectionMenu = languageSelectionMenu.update(
                    component: TextProcessingLanguageSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        sourceView: languageSelectionMenuDataValue.sourceView,
                        topLanguages: [],
                        selectedLanguageCode: languageSelectionMenuDataValue.currentLanguage,
                        currentStyle: languageSelectionMenuDataValue.currentStyle,
                        displayStyles: languageSelectionMenuDataValue.displayStyle,
                        completion: languageSelectionMenuDataValue.completion,
                        dismissed: { [weak state] in
                            languageSelectionMenuData = nil
                            state?.updated(transition: .immediate)
                        }
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(languageSelectionMenu
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                )
            }

            return context.availableSize
        }
    }
}

public class TextProcessingScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init(
        context: AccountContext,
        inputText: TextWithEntities,
        copyResult: @escaping (TextWithEntities) -> Void,
        completion: @escaping (TextWithEntities) -> Void
    ) {
        self.context = context

        super.init(
            context: context,
            component: TextProcessingSheetComponent(
                context: context,
                inputText: inputText,
                copyCurrentResult: copyResult,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class TitleComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isProcessing: Bool
    
    init(
        theme: PresentationTheme,
        title: String,
        isProcessing: Bool
    ) {
        self.theme = theme
        self.title = title
        self.isProcessing = isProcessing
    }
    
    static func ==(lhs: TitleComponent, rhs: TitleComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isProcessing != rhs.isProcessing {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var animationIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        
        private var component: TitleComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if component.isProcessing {
                let animationIcon: ComponentView<Empty>
                var animationIconTransition = transition
                if let current = self.animationIcon {
                    animationIcon = current
                } else {
                    animationIconTransition = animationIconTransition.withAnimation(.none)
                    animationIcon = ComponentView()
                    self.animationIcon = animationIcon
                }
                
                let animationIconSize = animationIcon.update(
                    transition: animationIconTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "SparklesEmoji"
                        ),
                        placeholderColor: nil,
                        startingPosition: .begin,
                        size: CGSize(width: 30.0, height: 30.0),
                        loop: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: 30.0, height: 30.0)
                )
                let animationIconFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - animationIconSize.height) * 0.5) - 2.0), size: animationIconSize)
                if let animationIconView = animationIcon.view {
                    if animationIconView.superview == nil {
                        self.addSubview(animationIconView)
                        animationIconView.alpha = 0.0
                    }
                    animationIconTransition.setFrame(view: animationIconView, frame: animationIconFrame)
                    transition.setAlpha(view: animationIconView, alpha: 1.0)
                }
            } else {
                if let animationIcon = self.animationIcon {
                    self.animationIcon = nil
                    if let animationIconView = animationIcon.view {
                        transition.setAlpha(view: animationIconView, alpha: 0.0, completion: { [weak animationIconView] _ in
                            animationIconView?.removeFromSuperview()
                        })
                    }
                }
            }

            return titleSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
