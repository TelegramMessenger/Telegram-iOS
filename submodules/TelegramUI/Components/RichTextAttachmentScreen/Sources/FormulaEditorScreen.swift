import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import ViewControllerComponent
import SheetComponent
import ListSectionComponent
import ListTextFieldItemComponent
import MultilineTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import TelegramPresentationData
import TelegramUIPreferences
import TelegramCore
import InstantPageUI

private let formulaInputTag = GenericComponentViewTag()

private final class FormulaPreviewItemComponent: Component {
    typealias EnvironmentType = Empty

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let latex: String
    let isPlaceholder: Bool

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        latex: String,
        isPlaceholder: Bool
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.latex = latex
        self.isPlaceholder = isPlaceholder
    }

    static func ==(lhs: FormulaPreviewItemComponent, rhs: FormulaPreviewItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.latex != rhs.latex {
            return false
        }
        if lhs.isPlaceholder != rhs.isPlaceholder {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private let scrollView: UIScrollView
        private let pageView: InstantPageV2View

        private var component: FormulaPreviewItemComponent?

        var customUpdateIsHighlighted: ((Bool) -> Void)?
        var enumerateSiblings: (((UIView) -> Void) -> Void)?
        let separatorInset: CGFloat = 0.0

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceHorizontal = true

            self.pageView = InstantPageV2View(renderContext: nil)

            super.init(frame: frame)

            self.addSubview(self.scrollView)
            self.scrollView.addSubview(self.pageView)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: FormulaPreviewItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let sideInset: CGFloat = 16.0
            let innerWidth = max(1.0, availableSize.width - sideInset * 2.0)

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let textColor: UIColor = component.isPlaceholder ? component.theme.list.itemPlaceholderTextColor : component.theme.list.itemPrimaryTextColor
            let pageTheme = formulaInstantPageTheme(presentationTheme: component.theme, textColor: textColor)
            let instantPage = InstantPage(
                blocks: [
                    .formula(latex: component.latex)
                ],
                media: [:],
                isComplete: true,
                rtl: false,
                url: "",
                views: nil
            )
            let webpage = TelegramMediaWebpage(
                webpageId: EngineMedia.Id(namespace: 0, id: 0),
                content: .Loaded(TelegramMediaWebpageLoadedContent(
                    url: "",
                    displayUrl: "",
                    hash: 0,
                    type: nil,
                    websiteName: nil,
                    title: nil,
                    text: nil,
                    embedUrl: nil,
                    embedType: nil,
                    embedSize: nil,
                    duration: nil,
                    author: nil,
                    isMediaLargeByDefault: nil,
                    imageIsVideoCover: false,
                    image: nil,
                    file: nil,
                    story: nil,
                    attributes: [],
                    instantPage: instantPage
                ))
            )

            let layout = layoutInstantPageV2(
                webpage: webpage,
                instantPage: instantPage,
                userLocation: .other,
                boundingWidth: innerWidth,
                horizontalInset: 0.0,
                theme: pageTheme,
                strings: component.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                cachedMessageSyntaxHighlight: nil,
                expandedDetails: [:],
                fitToWidth: true
                // Deliberately NOT scaled with Text Size: this theme is authored at a 22pt paragraph as a
                // stylised preview, not a replica of the bubble's 17pt table, so the bubble's
                // `baseDisplaySize / 17` would compound onto a base that is not 17 (33pt at the top step).
            )
            self.pageView.update(layout: layout, theme: pageTheme, animation: .None)

            let previewSize = CGSize(width: max(1.0, layout.contentSize.width), height: layout.contentSize.height)
            let scrollContentWidth = max(innerWidth, previewSize.width)
            let contentHeight: CGFloat = 84.0

            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: contentHeight)))
            self.scrollView.contentSize = CGSize(width: scrollContentWidth + sideInset * 2.0, height: contentHeight)

            let pageOriginX: CGFloat
            if previewSize.width <= innerWidth {
                pageOriginX = sideInset + floorToScreenPixels((innerWidth - previewSize.width) * 0.5)
                self.scrollView.setContentOffset(CGPoint(), animated: false)
            } else {
                pageOriginX = sideInset
            }
            let pageFrame = CGRect(
                origin: CGPoint(
                    x: pageOriginX,
                    y: floorToScreenPixels((contentHeight - previewSize.height) * 0.5)
                ),
                size: previewSize
            )
            transition.setFrame(view: self.pageView, frame: pageFrame)

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func formulaInstantPageTheme(presentationTheme: PresentationTheme, textColor: UIColor) -> InstantPageTheme {
    let paragraph = InstantPageTextAttributes(
        font: InstantPageFont(style: .sans, size: 22.0, lineSpacingFactor: 1.0),
        color: textColor
    )
    let caption = InstantPageTextAttributes(
        font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0),
        color: textColor
    )
    let categories = InstantPageTextCategories(
        kicker: caption,
        header: paragraph,
        subheader: paragraph,
        paragraph: paragraph,
        caption: caption,
        credit: caption,
        table: paragraph,
        article: paragraph,
        codeBlock: paragraph
    )
    let isDark = presentationTheme.overallDarkAppearance
    return InstantPageTheme(
        type: isDark ? .dark : .light,
        pageBackgroundColor: .clear,
        textCategories: categories,
        serif: false,
        codeBlockBackgroundColor: .clear,
        linkColor: presentationTheme.list.itemAccentColor,
        textHighlightColor: presentationTheme.list.itemAccentColor.withMultipliedAlpha(0.2),
        linkHighlightColor: presentationTheme.list.itemAccentColor.withMultipliedAlpha(0.2),
        markerColor: presentationTheme.list.itemAccentColor,
        panelBackgroundColor: .clear,
        panelHighlightedBackgroundColor: presentationTheme.list.itemHighlightedBackgroundColor,
        panelPrimaryColor: textColor,
        panelSecondaryColor: presentationTheme.list.itemSecondaryTextColor,
        panelAccentColor: presentationTheme.list.itemAccentColor,
        tableBorderColor: presentationTheme.list.itemBlocksSeparatorColor,
        tableHeaderColor: presentationTheme.list.itemBlocksBackgroundColor,
        controlColor: presentationTheme.list.itemAccentColor,
        imageTintColor: nil,
        overlayPanelColor: presentationTheme.list.itemBlocksBackgroundColor,
        separatorColor: presentationTheme.list.itemBlocksSeparatorColor,
        secondaryControlColor: presentationTheme.list.itemSecondaryTextColor,
        quoteAccentColor: .clear
    )
}

private final class FormulaEditorSheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let isEditing: Bool
    let initialLatex: String
    let placeholderLatex: String
    let latex: String
    let updateLatex: (String) -> Void
    let complete: (String) -> Void
    let dismiss: () -> Void

    init(
        context: AccountContext,
        isEditing: Bool,
        initialLatex: String,
        placeholderLatex: String,
        latex: String,
        updateLatex: @escaping (String) -> Void,
        complete: @escaping (String) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.isEditing = isEditing
        self.initialLatex = initialLatex
        self.placeholderLatex = placeholderLatex
        self.latex = latex
        self.updateLatex = updateLatex
        self.complete = complete
        self.dismiss = dismiss
    }

    static func ==(lhs: FormulaEditorSheetContent, rhs: FormulaEditorSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isEditing != rhs.isEditing {
            return false
        }
        if lhs.initialLatex != rhs.initialLatex {
            return false
        }
        if lhs.placeholderLatex != rhs.placeholderLatex {
            return false
        }
        if lhs.latex != rhs.latex {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let latexSection = ComponentView<Empty>()
        private let resultSection = ComponentView<Empty>()

        private var component: FormulaEditorSheetContent?
        private var currentLatex = ""

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: FormulaEditorSheetContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.currentLatex = component.latex

            self.background.parentState = state
            self.cancelButton.parentState = state
            self.doneButton.parentState = state
            self.title.parentState = state
            self.latexSection.parentState = state
            self.resultSection.parentState = state

            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme.withModalBlocksBackground()
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: availableSize.width, height: 38.0)

            let backgroundSize = self.background.update(
                transition: .immediate,
                component: AnyComponent(RoundedRectangle(color: theme.list.blocksBackgroundColor, cornerRadius: 8.0)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: backgroundSize))
            }

            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
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
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: CGRect(origin: CGPoint(x: sideInset, y: 16.0), size: cancelButtonSize))
            }

            let trimmedLatex = component.latex.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = !trimmedLatex.isEmpty
            let doneButtonSize = self.doneButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: isValid ? theme.list.itemCheckColors.fillColor : theme.list.itemCheckColors.fillColor.desaturated().withMultipliedAlpha(0.5),
                    isDark: theme.overallDarkAppearance,
                    state: .tintedGlass,
                    isEnabled: isValid,
                    component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Done",
                            tintColor: theme.list.itemCheckColors.foregroundColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        let latex = self.currentLatex.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !latex.isEmpty else {
                            return
                        }
                        component.complete(latex)
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    self.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - sideInset - doneButtonSize.width, y: 16.0), size: doneButtonSize))
            }

            let constrainedTitleWidth = availableSize.width - (sideInset + barButtonSize.width + 8.0) * 2.0
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.isEditing ? environment.strings.RichText_FormulaEdit : environment.strings.RichText_FormulaAdd,
                    font: Font.bold(17.0),
                    color: theme.list.itemPrimaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: constrainedTitleWidth, height: 40.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: contentSize.height - titleSize.height * 0.5),
                    size: titleSize
                ))
            }
            contentSize.height += titleSize.height
            contentSize.height += 40.0

            let headerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let sectionWidth = availableSize.width - sideInset * 2.0
            let latexSectionSize = self.latexSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.RichText_FormulaSectionSourceTitle,
                            font: headerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "latex", component: AnyComponent(
                            ListTextFieldItemComponent(
                                style: .glass,
                                theme: theme,
                                initialText: component.initialLatex,
                                placeholder: component.placeholderLatex,
                                hasClearButton: false,
                                autocapitalizationType: .none,
                                autocorrectionType: .no,
                                returnKeyType: .done,
                                updated: { [weak self] text in
                                    self?.currentLatex = text
                                    component.updateLatex(text)
                                },
                                onReturn: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    let latex = self.currentLatex.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !latex.isEmpty else {
                                        return
                                    }
                                    component.complete(latex)
                                },
                                tag: formulaInputTag
                            )
                        ))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let latexSectionView = self.latexSection.view {
                if latexSectionView.superview == nil {
                    self.addSubview(latexSectionView)
                }
                latexSectionView.clipsToBounds = true
                latexSectionView.layer.cornerRadius = 10.0
                transition.setFrame(view: latexSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentSize.height), size: latexSectionSize))
            }
            contentSize.height += latexSectionSize.height
            contentSize.height += 30.0

            let previewLatex: String
            let previewIsPlaceholder: Bool
            if component.latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                previewLatex = component.placeholderLatex
                previewIsPlaceholder = true
            } else {
                previewLatex = component.latex
                previewIsPlaceholder = false
            }

            let resultSectionSize = self.resultSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.RichText_FormulaSectionResultTitle,
                            font: headerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "preview", component: AnyComponent(
                            FormulaPreviewItemComponent(
                                context: component.context,
                                theme: theme,
                                strings: environment.strings,
                                latex: previewLatex,
                                isPlaceholder: previewIsPlaceholder
                            )
                        ))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let resultSectionView = self.resultSection.view {
                if resultSectionView.superview == nil {
                    self.addSubview(resultSectionView)
                }
                resultSectionView.clipsToBounds = true
                resultSectionView.layer.cornerRadius = 10.0
                transition.setFrame(view: resultSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentSize.height), size: resultSectionSize))
            }
            contentSize.height += resultSectionSize.height
            contentSize.height += 32.0

            contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)

            return contentSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class FormulaEditorSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    private static let placeholderLatexes: [String] = [
        #"e^{I\pi}=-1"#,
        #"x_{1,2}=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#,
        #"x^n+y^n=z^n"#,
        #"\sin^2\alpha+\cos^2\alpha=1"#
    ]

    private let context: AccountContext
    private let initialValue: String?
    private let completion: (String) -> Void

    init(context: AccountContext, initialValue: String?, completion: @escaping (String) -> Void) {
        self.context = context
        self.initialValue = initialValue
        self.completion = completion
    }

    static func ==(lhs: FormulaEditorSheetComponent, rhs: FormulaEditorSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialValue != rhs.initialValue {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: FormulaEditorSheetComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var initialLatex: String?
        private var placeholderLatex: String?
        private var latex: String?
        private var isDismissing = false

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func dismiss(animated: Bool) {
            guard let environment = self.environment, !self.isDismissing else {
                return
            }
            self.isDismissing = true

            let performDismiss = {
                if let controller = environment.controller() {
                    controller.dismiss(completion: nil)
                }
            }

            if animated {
                self.animateOut.invoke(Action { _ in
                    performDismiss()
                })
            } else {
                performDismiss()
            }
        }

        private func complete(latex: String) {
            guard let component = self.component, !self.isDismissing else {
                return
            }
            component.completion(latex)
            self.dismiss(animated: true)
        }

        func update(component: FormulaEditorSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                let initialLatex = component.initialValue ?? ""
                self.initialLatex = initialLatex
                self.latex = initialLatex
                self.placeholderLatex = FormulaEditorSheetComponent.placeholderLatexes.randomElement() ?? FormulaEditorSheetComponent.placeholderLatexes[0]
            }

            self.component = component
            self.state = state

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment

            let initialLatex = self.initialLatex ?? component.initialValue ?? ""
            let placeholderLatex = self.placeholderLatex ?? FormulaEditorSheetComponent.placeholderLatexes[0]
            let latex = self.latex ?? initialLatex

            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] animated in
                    self?.dismiss(animated: animated)
                }
            )

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(FormulaEditorSheetContent(
                        context: component.context,
                        isEditing: component.initialValue != nil,
                        initialLatex: initialLatex,
                        placeholderLatex: placeholderLatex,
                        latex: latex,
                        updateLatex: { [weak self] text in
                            self?.latex = text
                            Queue.mainQueue().justDispatch { [weak self] in
                                self?.state?.updated(transition: .immediate)
                            }
                        },
                        complete: { [weak self] latex in
                            self?.complete(latex: latex)
                        },
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        }
                    )),
                    style: .glass,
                    backgroundColor: .blur(.dark),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    isScrollEnabled: false,
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: sheetSize))
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class FormulaEditorScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        initialValue: String? = nil,
        completion: @escaping (String) -> Void
    ) {
        super.init(
            context: context,
            component: FormulaEditorSheetComponent(
                context: context,
                initialValue: initialValue,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let view = self.node.hostView.findTaggedView(tag: formulaInputTag) as? ListTextFieldItemComponent.View {
            view.activateInput()
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
