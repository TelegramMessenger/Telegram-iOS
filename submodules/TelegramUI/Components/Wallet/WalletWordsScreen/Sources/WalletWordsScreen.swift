import Foundation
import LottieSettings
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent
import ButtonComponent
import BundleIconComponent
import ResizableSheetComponent
import GlassBarButtonComponent

private extension WalletWordsScreenMode {
    var retainsVerificationScreens: Bool {
        switch self {
        case .replacement, .backupDisable:
            return true
        case .view, .verify:
            return false
        }
    }

    var verifiesRotatedKey: Bool {
        if case let .backupDisable(updateSecretPhrase) = self {
            return updateSecretPhrase
        }
        return false
    }

    var allowsRepeatedVerificationCompletion: Bool {
        if case .backupDisable = self {
            return true
        }
        return false
    }
}

private final class WalletWordsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let words: [String]
    let mode: WalletWordsScreenMode
    let bottomInset: CGFloat

    init(context: AccountContext, words: [String], mode: WalletWordsScreenMode, bottomInset: CGFloat) {
        self.context = context
        self.words = words
        self.mode = mode
        self.bottomInset = bottomInset
    }

    static func ==(lhs: WalletWordsScreenComponent, rhs: WalletWordsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.words != rhs.words {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        return true
    }

    final class View: UIView {
        private final class WordItem {
            let number = ComponentView<Empty>()
            let word = ComponentView<Empty>()
        }

        private let animation = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private var wordItems: [WordItem] = []

        private let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletWordsScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme
            self.backgroundColor = .clear

            let titleText: String
            let bodyText: String
            switch component.mode {
            case .view, .verify, .backupDisable(updateSecretPhrase: false):
                titleText = environment.strings.Wallet_Words_Title
                bodyText = environment.strings.Wallet_SecretPhraseInfo
            case .replacement, .backupDisable(updateSecretPhrase: true):
                titleText = environment.strings.Wallet_Words_NewTitle
                bodyText = environment.strings.Wallet_Words_NewText
            }
            let sideInset = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let contentWidth = max(0.0, min(430.0, availableSize.width - sideInset * 2.0))
            var contentHeight: CGFloat = 33.0

            self.animation.parentState = state
            let animationSize = CGSize(width: 100.0, height: 100.0)
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "WalletWordList"),
                    startingPosition: .begin,
                    size: animationSize,
                    loop: false,
                    playOnce: self.playAnimation,
                    lottieSettings: component.context.lottieRenderingSettings
                )),
                environment: {},
                containerSize: animationSize
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.addSubview(animationView)
                }
                transition.setFrame(
                    view: animationView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - animationSize.width) / 2.0), y: contentHeight),
                        size: animationSize
                    )
                )
            }
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playAnimation.invoke(Void())
            }
            contentHeight += animationSize.height + 8.0

            self.title.parentState = state
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(28.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: contentHeight),
                        size: titleSize
                    )
                )
            }
            contentHeight += titleSize.height + 11.0
            
            self.text.parentState = state
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: bodyText,
                        font: Font.regular(16.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(
                    view: textView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - textSize.width) / 2.0), y: contentHeight),
                        size: textSize
                    )
                )
            }
            contentHeight += textSize.height
            contentHeight += 25.0

            while self.wordItems.count < component.words.count {
                self.wordItems.append(WordItem())
            }
            if self.wordItems.count > component.words.count {
                for item in self.wordItems[component.words.count...] {
                    item.number.view?.removeFromSuperview()
                    item.word.view?.removeFromSuperview()
                }
                self.wordItems.removeLast(self.wordItems.count - component.words.count)
            }

            let wordListWidth = min(contentWidth, 296.0)
            let minimumColumnWidth: CGFloat = 116.0
            let columnSpacing = min(40.0, max(16.0, wordListWidth - minimumColumnWidth * 2.0))
            let columnWidth = max(0.0, floorToScreenPixels((wordListWidth - columnSpacing) / 2.0))
            let wordListLayoutWidth = columnWidth * 2.0 + columnSpacing
            let wordListX = floorToScreenPixels((availableSize.width - wordListLayoutWidth) / 2.0)
            let numberWidth: CGFloat = 30.0
            let numberWordSpacing: CGFloat = 8.0
            let wordWidth = max(0.0, columnWidth - numberWidth - numberWordSpacing)
            let rowSpacing: CGFloat = 12.0
            let leftCount = min(12, (component.words.count + 1) / 2)
            let rightCount = max(0, component.words.count - leftCount)
            let rowCount = max(leftCount, rightCount)

            for rowIndex in 0 ..< rowCount {
                var layouts: [(index: Int, columnX: CGFloat, numberSize: CGSize, wordSize: CGSize)] = []
                let wordIndices: [Int?] = [
                    rowIndex < leftCount ? rowIndex : nil,
                    rowIndex < rightCount ? rowIndex + leftCount : nil
                ]

                for columnIndex in 0 ..< wordIndices.count {
                    guard let wordIndex = wordIndices[columnIndex] else {
                        continue
                    }

                    let item = self.wordItems[wordIndex]
                    item.number.parentState = state
                    item.word.parentState = state

                    let numberSize = item.number.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "\(wordIndex + 1).",
                                font: Font.with(size: 17.0, traits: .monospacedNumbers),
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            horizontalAlignment: .right,
                            maximumNumberOfLines: 1
                        )),
                        environment: {},
                        containerSize: CGSize(width: numberWidth, height: 100.0)
                    )
                    let wordSize = item.word.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.words[wordIndex],
                                font: Font.medium(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        environment: {},
                        containerSize: CGSize(width: wordWidth, height: 1000.0)
                    )

                    if let numberView = item.number.view, numberView.superview == nil {
                        self.addSubview(numberView)
                    }
                    if let wordView = item.word.view, wordView.superview == nil {
                        self.addSubview(wordView)
                    }

                    layouts.append((
                        index: wordIndex,
                        columnX: wordListX + CGFloat(columnIndex) * (columnWidth + columnSpacing),
                        numberSize: numberSize,
                        wordSize: wordSize
                    ))
                }

                var rowHeight: CGFloat = 0.0
                for layout in layouts {
                    rowHeight = max(rowHeight, max(layout.numberSize.height, layout.wordSize.height))
                }

                for layout in layouts {
                    let item = self.wordItems[layout.index]
                    if let numberView = item.number.view {
                        transition.setFrame(
                            view: numberView,
                            frame: CGRect(
                                origin: CGPoint(
                                    x: layout.columnX + numberWidth - layout.numberSize.width,
                                    y: contentHeight + floor((rowHeight - layout.numberSize.height) / 2.0)
                                ),
                                size: layout.numberSize
                            )
                        )
                    }
                    if let wordView = item.word.view {
                        transition.setFrame(
                            view: wordView,
                            frame: CGRect(
                                origin: CGPoint(
                                    x: layout.columnX + numberWidth + numberWordSpacing,
                                    y: contentHeight + floor((rowHeight - layout.wordSize.height) / 2.0)
                                ),
                                size: layout.wordSize
                            )
                        )
                    }
                }

                contentHeight += rowHeight
                if rowIndex != rowCount - 1 {
                    contentHeight += rowSpacing
                }
            }

            contentHeight += 24.0
            contentHeight += component.bottomInset

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private final class WalletWordsSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let words: [String]
    let mode: WalletWordsScreenMode

    init(context: AccountContext, words: [String], mode: WalletWordsScreenMode) {
        self.context = context
        self.words = words
        self.mode = mode
    }

    static func ==(lhs: WalletWordsSheetComponent, rhs: WalletWordsSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.words != rhs.words {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    let animateDismissal = {
                        animateOut.invoke(Action { _ in
                            controller()?.dismiss(completion: nil)
                        })
                    }
                    if let controller = controller() as? WalletWordsScreen {
                        controller.requestDismiss(completion: animateDismissal)
                    } else {
                        animateDismissal()
                    }
                } else {
                    controller()?.dismiss(completion: nil)
                }
            }

            let theme = environment.theme.withModalBlocksBackground()
            let bottomInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let contentBottomInset = bottomInsets.bottom + 52.0 + 16.0

            let buttonTitle: String
            switch context.component.mode {
            case .view, .verify:
                buttonTitle = environment.strings.Common_Done
            case .replacement:
                buttonTitle = environment.strings.Wallet_Continue
            case .backupDisable:
                buttonTitle = environment.strings.Wallet_Continue
            }
            let sheetComponent = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletWordsScreenComponent(
                        context: context.component.context,
                        words: context.component.words,
                        mode: context.component.mode,
                        bottomInset: contentBottomInset
                    )),
                    titleItem: nil,
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(
                            id: "close",
                            component: AnyComponent(BundleIconComponent(
                                name: "Navigation/Close",
                                tintColor: theme.chat.inputPanel.panelControlColor
                            ))
                        ),
                        action: { _ in
                            dismiss(true)
                        }
                    )),
                    rightItem: nil,
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(Text(
                                text: buttonTitle,
                                font: Font.semibold(17.0),
                                color: theme.list.itemCheckColors.foregroundColor
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: {
                            (controller() as? WalletWordsScreen)?.complete()
                        }
                    )),
                    backgroundColor: .color(theme.list.modalPlainBackgroundColor),
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
            context.add(sheetComponent.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

            return context.availableSize
        }
    }
}

public final class WalletWordsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let words: [String]
    private let mode: WalletWordsScreenMode
    private let completion: (() -> Void)?
    private let displayedAt = Date()
    private let idleTimerExtensionDisposable = MetaDisposable()
    private let backgroundOrLockDisposable = MetaDisposable()
    private var pendingAutomaticDismissal = false
    private var automaticDismissalScheduled = false
    private var isVerifying = false
    private var isDismissingProgrammatically = false
    private weak var cancelDisableBackupController: ViewController?

    public convenience init(context: AccountContext, words: [String], verify: Bool, dismissOnBackgroundOrLock: Bool = false, completion: (() -> Void)?) {
        self.init(
            context: context,
            words: words,
            mode: verify ? .verify : .view,
            dismissOnBackgroundOrLock: dismissOnBackgroundOrLock,
            completion: completion
        )
    }

    public init(context: AccountContext, words: [String], mode: WalletWordsScreenMode, dismissOnBackgroundOrLock: Bool = false, completion: (() -> Void)?) {
        self.context = context
        self.words = words
        self.mode = mode
        self.completion = completion

        super.init(
            context: context,
            component: WalletWordsSheetComponent(context: context, words: words, mode: mode),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        self.idleTimerExtensionDisposable.set(context.sharedContext.applicationBindings.pushIdleTimerExtension())
        if dismissOnBackgroundOrLock {
            self.backgroundOrLockDisposable.set((combineLatest(
                context.sharedContext.applicationBindings.applicationInForeground,
                context.sharedContext.appLockContext.isPasscodeLocked
            )
            |> filter { foreground, locked in !foreground || locked }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else { return }
                self.pendingAutomaticDismissal = true
                self.scheduleAutomaticDismissal()
            }))
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
        self.backgroundOrLockDisposable.dispose()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scheduleAutomaticDismissal()
    }

    private func scheduleAutomaticDismissal() {
        guard self.pendingAutomaticDismissal, !self.automaticDismissalScheduled else { return }
        self.automaticDismissalScheduled = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.automaticDismissalScheduled = false
            if let navigation = self.navigationController as? NavigationController {
                guard navigation.viewControllers.contains(where: { $0 === self }) else { return }
            } else if self.presentingViewController == nil {
                return
            }
            self.dismiss(animated: false)
        }
    }

    fileprivate func requestDismiss(completion: @escaping () -> Void) {
        guard case .backupDisable = self.mode, !self.isDismissingProgrammatically else {
            completion()
            return
        }
        guard self.cancelDisableBackupController == nil else {
            return
        }

        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let controller = textAlertController(
            context: self.context,
            title: strings.Wallet_Backup_CancelDisablingTitle,
            text: strings.Wallet_Backup_CancelDisablingText,
            actions: [
                TextAlertAction(type: .defaultAction, title: strings.Wallet_Backup_CancelDisabling, action: completion),
                TextAlertAction(type: .genericAction, title: strings.Wallet_Continue, action: {})
            ],
            actionLayout: .vertical,
            dismissOnOutsideTap: false
        )
        self.cancelDisableBackupController = controller
        self.present(controller, in: .window(.root))
    }

    fileprivate func complete() {
        guard !self.pendingAutomaticDismissal, !self.words.isEmpty, !self.isVerifying else {
            return
        }
        if self.mode.retainsVerificationScreens, Date().timeIntervalSince(self.displayedAt) < 10.0 {
            self.present(textAlertController(
                context: self.context,
                title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Words_TooFastTitle,
                text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Words_TooFastText,
                actions: [TextAlertAction(type: .genericAction, title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Words_TooFastAction, action: {
                })]
            ), in: .window(.root))
            return
        }
        if self.mode != .view {
            self.isVerifying = true
            let wordsController: ViewController = self
            let verificationController = self.context.sharedContext.makeWalletImportScreen(
                context: self.context,
                mode: .verify(
                    words: self.words,
                    keyRotation: self.mode.verifiesRotatedKey,
                    allowsRepeatedCompletion: self.mode.allowsRepeatedVerificationCompletion
                ),
                completion: { [weak self, weak wordsController] in
                    guard let self, let wordsController else {
                        return
                    }
                    let navigationController = wordsController.navigationController as? NavigationController
                    let remainingViewControllers: [UIViewController]?
                    if let navigationController,
                       let wordsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === wordsController }) {
                        remainingViewControllers = Array(navigationController.viewControllers.prefix(upTo: wordsControllerIndex))
                    } else {
                        remainingViewControllers = nil
                    }

                    self.isVerifying = false
                    self.completion?()

                    if self.mode.retainsVerificationScreens {
                        return
                    }

                    guard let navigationController, let remainingViewControllers else {
                        wordsController.dismiss()
                        return
                    }
                    navigationController.setViewControllers(remainingViewControllers, animated: true)
                }
            )
            if let verificationController = verificationController as? ViewControllerComponentContainer {
                verificationController.wasDismissed = { [weak self] in
                    self?.isVerifying = false
                }
            }
            self.push(verificationController)
        } else {
            self.completion?()
            self.dismissAnimated()
        }
    }

    public func dismissAnimated() {
        self.isDismissingProgrammatically = true
        defer {
            self.isDismissingProgrammatically = false
        }
        if let view = self.node.hostView.findTaggedView(
            tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.dismiss()
        }
    }
}
