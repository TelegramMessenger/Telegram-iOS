import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import ResizableSheetComponent
import NavigationStackComponent
import BalancedTextComponent
import MultilineTextComponent
import ScrollComponent
import TextSelectionNode
import Pasteboard
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import WalletContext
import WalletCardComponent
import AlertUI

fileprivate enum WalletTransferFinishResult {
    case cancelled
    case confirmed
}

private final class WalletTransferSigningTextComponent: Component {
    typealias EnvironmentType = (Empty, ScrollChildEnvironment)

    let theme: PresentationTheme
    let strings: PresentationStrings
    let text: NSAttributedString
    let controller: () -> ViewController?

    init(theme: PresentationTheme, strings: PresentationStrings, text: NSAttributedString, controller: @escaping () -> ViewController?) {
        self.theme = theme
        self.strings = strings
        self.text = text
        self.controller = controller
    }

    static func ==(lhs: WalletTransferSigningTextComponent, rhs: WalletTransferSigningTextComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.strings === rhs.strings && lhs.text == rhs.text
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private var selection: TextSelectionNode?
        private var component: WalletTransferSigningTextComponent?

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let selection = self.selection,
               let result = selection.view.hitTest(self.convert(point, to: selection.view), with: event) {
                return result
            }
            return super.hitTest(point, with: event)
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if self.bounds.contains(point) { return true }
            if let selection = self.selection {
                return selection.view.hitTest(self.convert(point, to: selection.view), with: event) != nil
            }
            return false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil { self.selection?.cancelSelection() }
        }

        private func removeSelection() {
            guard let selection = self.selection else { return }
            self.selection = nil
            selection.cancelSelection()
            selection.highlightAreaNode.view.removeFromSuperview()
            selection.view.removeFromSuperview()
        }

        func update(component: WalletTransferSigningTextComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            if let previous = self.component, previous != component {
                self.removeSelection()
            }
            self.component = component
            self.text.parentState = state
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(component.text),
                    horizontalAlignment: .left,
                    maximumNumberOfLines: 0,
                    insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)
                )),
                environment: {},
                containerSize: availableSize
            )
            if let textView = self.text.view as? MultilineTextComponent.View {
                if textView.superview == nil { self.addSubview(textView) }
                transition.setFrame(view: textView, frame: CGRect(origin: .zero, size: textSize))

                if self.selection == nil && !component.text.string.isEmpty {
                    let accentColor = component.theme.actionSheet.controlAccentColor
                    let selection = TextSelectionNode(
                        theme: TextSelectionTheme(
                            selection: accentColor.withMultipliedAlpha(0.5),
                            knob: accentColor,
                            isDark: component.theme.overallDarkAppearance
                        ),
                        strings: component.strings,
                        textNodeOrView: .view(textView),
                        updateIsActive: { _ in },
                        present: { [weak self] controller, arguments in
                            self?.component?.controller()?.presentInGlobalOverlay(controller, with: arguments)
                        },
                        rootView: { [weak self] in
                            return self?.component?.controller()?.displayNode.view
                        },
                        performAction: { text, action in
                            if action == .copy {
                                storeMessageTextInPasteboard(text.string, entities: nil)
                            }
                        }
                    )
                    selection.enableCopy = true
                    selection.enableLookup = false
                    selection.enableTranslate = false
                    selection.enableShare = false
                    selection.enableSpeak = false
                    selection.enableQuote = false
                    selection.enableAutomaticScrolling = false
                    selection.cancelSelectionOnOutsideTap = true
                    self.selection = selection
                    self.insertSubview(selection.highlightAreaNode.view, belowSubview: textView)
                    self.addSubview(selection.view)
                }
                if let selection = self.selection {
                    let needsLayout = selection.frame.size != textSize
                    selection.frame = CGRect(origin: .zero, size: textSize)
                    selection.highlightAreaNode.frame = selection.frame
                    if needsLayout { selection.updateLayout() }
                }
            }
            return CGSize(width: availableSize.width, height: max(20.0, textSize.height))
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}

private final class WalletTransferSigningCardComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let content: WalletTransferPresentation.SigningContent
    let controller: () -> ViewController?
    let scrollViewUpdated: (UIScrollView?) -> Void

    init(theme: PresentationTheme, strings: PresentationStrings, content: WalletTransferPresentation.SigningContent, controller: @escaping () -> ViewController?, scrollViewUpdated: @escaping (UIScrollView?) -> Void) {
        self.theme = theme
        self.strings = strings
        self.content = content
        self.controller = controller
        self.scrollViewUpdated = scrollViewUpdated
    }

    static func ==(lhs: WalletTransferSigningCardComponent, rhs: WalletTransferSigningCardComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.strings === rhs.strings && lhs.content == rhs.content
    }

    final class View: UIView {
        private let scroll = ComponentView<Empty>()
        private let scrollState = ScrollComponent<Empty>.ExternalState()
        private let resetScroll = ActionSlot<CGPoint?>()
        private let warningIcon = ComponentView<Empty>()
        private let warningTitle = ComponentView<Empty>()
        private let warningText = ComponentView<Empty>()
        private let warningImage = UIImage(systemName: "exclamationmark.circle.fill")
        private var content: WalletTransferPresentation.SigningContent?

        func update(component: WalletTransferSigningCardComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            transition.setBackgroundColor(view: self, color: component.theme.list.itemModalBlocksBackgroundColor)
            transition.setCornerRadius(layer: self.layer, cornerRadius: 28.0)
            self.clipsToBounds = true
            let contentWidth = max(1.0, availableSize.width - 32.0)
            let contentChanged = self.content != component.content
            self.content = component.content

            if case .binary = component.content {
                self.scroll.view?.removeFromSuperview()
                component.scrollViewUpdated(nil)
                self.warningIcon.parentState = state
                let iconSize = self.warningIcon.update(
                    transition: transition,
                    component: AnyComponent(Image(image: self.warningImage, tintColor: component.theme.list.itemDestructiveColor, size: CGSize(width: 16.0, height: 16.0))),
                    environment: {},
                    containerSize: CGSize(width: 16.0, height: 16.0)
                )
                if let iconView = self.warningIcon.view {
                    if iconView.superview == nil { self.addSubview(iconView) }
                    transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: 16.0, y: 18.0), size: iconSize))
                }
                self.warningTitle.parentState = state
                let titleSize = self.warningTitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Wallet_Sign_BinaryContent, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, contentWidth - 22.0), height: .greatestFiniteMagnitude)
                )
                if let titleView = self.warningTitle.view {
                    if titleView.superview == nil { self.addSubview(titleView) }
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: 38.0, y: 14.0), size: titleSize))
                }
                self.warningText.parentState = state
                let textSize = self.warningText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Wallet_Sign_BinaryWarning, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
                )
                if let textView = self.warningText.view {
                    if textView.superview == nil { self.addSubview(textView) }
                    transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: 16.0, y: 14.0 + titleSize.height + 2.0), size: textSize))
                }
                return CGSize(width: availableSize.width, height: 14.0 + titleSize.height + 2.0 + textSize.height + 14.0)
            }
            self.warningIcon.view?.removeFromSuperview()
            self.warningTitle.view?.removeFromSuperview()
            self.warningText.view?.removeFromSuperview()

            let text = NSMutableAttributedString()
            switch component.content {
            case let .text(value):
                text.append(NSAttributedString(string: value, font: Font.with(size: 17.0, design: .monospace), textColor: component.theme.list.itemPrimaryTextColor))
            case let .message(groups):
                let font = Font.with(size: 14.0, design: .monospace)
                for (groupIndex, fields) in groups.enumerated() {
                    if groupIndex != 0 { text.append(NSAttributedString(string: "\n\n", font: font, textColor: component.theme.list.itemPrimaryTextColor)) }
                    for (fieldIndex, field) in fields.enumerated() {
                        if fieldIndex != 0 { text.append(NSAttributedString(string: "\n", font: font, textColor: component.theme.list.itemPrimaryTextColor)) }
                        text.append(NSAttributedString(string: field.name + ": ", font: font, textColor: component.theme.list.itemSecondaryTextColor))
                        text.append(NSAttributedString(string: field.value, font: font, textColor: component.theme.list.itemPrimaryTextColor))
                    }
                }
            case .binary:
                break
            }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byCharWrapping
            text.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.length))

            let scrollComponent = AnyComponent(ScrollComponent<Empty>(
                content: AnyComponent(WalletTransferSigningTextComponent(theme: component.theme, strings: component.strings, text: text, controller: component.controller)),
                externalState: self.scrollState,
                contentInsets: .zero,
                contentOffsetUpdated: { _, _ in },
                contentOffsetWillCommit: { _ in },
                resetScroll: self.resetScroll
            ))
            self.scroll.parentState = state
            let _ = self.scroll.update(transition: transition, component: scrollComponent, environment: {}, containerSize: CGSize(width: contentWidth, height: 320.0))
            let height = min(320.0, self.scrollState.contentHeight)
            let scrollSize = self.scroll.update(transition: transition, component: scrollComponent, environment: {}, containerSize: CGSize(width: contentWidth, height: height))
            if contentChanged { self.resetScroll.invoke(nil) }
            if let scrollView = self.scroll.view {
                if scrollView.superview == nil { self.addSubview(scrollView) }
                transition.setFrame(view: scrollView, frame: CGRect(origin: CGPoint(x: 16.0, y: 14.0), size: scrollSize))
            }
            component.scrollViewUpdated(height >= 320.0 ? self.scroll.view as? UIScrollView : nil)
            return CGSize(width: availableSize.width, height: scrollSize.height + 28.0)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}

private final class WalletTransferSheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let request: WalletContext.TonConnectOperationRequest
    let walletState: WalletContext.State?
    let bottomInset: CGFloat
    let infoPressed: () -> Void
    let scrollViewUpdated: (UIScrollView?) -> Void

    init(
        context: AccountContext,
        request: WalletContext.TonConnectOperationRequest,
        walletState: WalletContext.State?,
        bottomInset: CGFloat,
        infoPressed: @escaping () -> Void,
        scrollViewUpdated: @escaping (UIScrollView?) -> Void
    ) {
        self.context = context
        self.request = request
        self.walletState = walletState
        self.bottomInset = bottomInset
        self.infoPressed = infoPressed
        self.scrollViewUpdated = scrollViewUpdated
    }

    static func ==(lhs: WalletTransferSheetContent, rhs: WalletTransferSheetContent) -> Bool {
        return lhs.request == rhs.request
            && lhs.walletState == rhs.walletState
            && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private let appIcon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let domain = ComponentView<Empty>()
        private let card = ComponentView<Empty>()
        private let fee = ComponentView<Empty>()
        private let dataTitle = ComponentView<Empty>()
        private let signingCard = ComponentView<Empty>()
        private let signingExplanation = ComponentView<Empty>()
        private let signingSubmission = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransferSheetContent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme
            transition.setBackgroundColor(view: self, color: theme.list.modalPlainBackgroundColor)

            let safeContentWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right
            )
            let contentCenterX = environment.safeInsets.left + safeContentWidth / 2.0
            let textWidth = max(1.0, safeContentWidth - 48.0)
            let primaryTextColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let accentColor = theme.actionSheet.controlAccentColor

            let presentation = WalletTransferPresentation(request: component.request, walletState: component.walletState)
            if let signingContent = presentation.signingContent(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat) {
                self.appIcon.view?.isHidden = true
                self.title.view?.isHidden = true
                self.domain.view?.isHidden = true
                self.card.view?.isHidden = true
                transition.setBackgroundColor(view: self, color: theme.list.modalBlocksBackgroundColor)

                let sideInset: CGFloat = 16.0
                let cardWidth = max(1.0, safeContentWidth - sideInset * 2.0)
                let cardX = environment.safeInsets.left + sideInset
                var contentHeight: CGFloat = 90.0
                func addText(_ text: String, view: ComponentView<Empty>, font: UIFont, topInset: CGFloat) {
                    guard !text.isEmpty else {
                        view.view?.isHidden = true
                        return
                    }
                    contentHeight += topInset
                    view.parentState = state
                    let size = view.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: text, font: font, textColor: secondaryTextColor)),
                            maximumNumberOfLines: 0
                        )),
                        environment: {},
                        containerSize: CGSize(width: max(1.0, cardWidth - 32.0), height: .greatestFiniteMagnitude)
                    )
                    if let textView = view.view {
                        if textView.superview == nil { self.addSubview(textView) }
                        textView.isHidden = false
                        transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: cardX + 16.0, y: contentHeight), size: size))
                    }
                    contentHeight += size.height
                }
                addText(environment.strings.Wallet_Sign_Data, view: self.dataTitle, font: Font.semibold(17.0), topInset: 0.0)
                contentHeight += 12.0
                self.signingCard.parentState = state
                let cardSize = self.signingCard.update(
                    transition: transition,
                    component: AnyComponent(WalletTransferSigningCardComponent(
                        theme: theme,
                        strings: environment.strings,
                        content: signingContent,
                        controller: environment.controller,
                        scrollViewUpdated: component.scrollViewUpdated
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: availableSize.height)
                )
                if let cardView = self.signingCard.view {
                    if cardView.superview == nil { self.addSubview(cardView) }
                    transition.setFrame(view: cardView, frame: CGRect(origin: CGPoint(x: cardX, y: contentHeight), size: cardSize))
                }
                contentHeight += cardSize.height
                addText(signingContent.explanation(strings: environment.strings) ?? "", view: self.signingExplanation, font: Font.regular(14.0), topInset: 10.0)
                addText(presentation.submissionText(strings: environment.strings) ?? "", view: self.signingSubmission, font: Font.regular(14.0), topInset: 16.0)
                addText(presentation.feeText(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat), view: self.fee, font: Font.regular(14.0), topInset: 20.0)
                return CGSize(width: availableSize.width, height: contentHeight + 16.0 + component.bottomInset)
            }
            self.dataTitle.view?.isHidden = true
            self.signingCard.view?.removeFromSuperview()
            component.scrollViewUpdated(nil)
            self.signingExplanation.view?.isHidden = true
            self.signingSubmission.view?.isHidden = true
            self.appIcon.view?.isHidden = false
            self.title.view?.isHidden = false
            self.domain.view?.isHidden = false
            self.card.view?.isHidden = false
            self.fee.view?.isHidden = false

            var contentHeight: CGFloat = 32.0

            self.appIcon.parentState = state
            let appIconSize = CGSize(width: 88.0, height: 88.0)
            let _ = self.appIcon.update(
                transition: transition,
                component: AnyComponent(WalletConnectAppIconComponent(
                    context: component.context,
                    applicationName: component.request.applicationName,
                    icon: component.request.icon
                )),
                environment: {},
                containerSize: appIconSize
            )
            if let appIconView = self.appIcon.view {
                if appIconView.superview == nil {
                    self.addSubview(appIconView)
                }
                appIconView.clipsToBounds = true
                transition.setCornerRadius(layer: appIconView.layer, cornerRadius: appIconSize.width * 0.5)
                transition.setFrame(
                    view: appIconView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - appIconSize.width / 2.0), y: contentHeight),
                        size: appIconSize
                    )
                )
            }
            contentHeight += appIconSize.height
            contentHeight += 18.0

            self.title.parentState = state
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Sign_ConfirmAction,
                        font: Font.bold(22.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - titleSize.width / 2.0), y: contentHeight),
                        size: titleSize
                    )
                )
            }
            contentHeight += titleSize.height
            contentHeight += 4.0

            let domainItems: [AnyComponentWithIdentity<Empty>] = [AnyComponentWithIdentity(
                id: "domain",
                component: AnyComponent(Text(
                    text: component.request.domain,
                    font: Font.semibold(15.0),
                    color: accentColor
                ))
            )]
            self.domain.parentState = state
            let domainSize = self.domain.update(
                transition: .immediate,
                component: AnyComponent(HStack<Empty>(domainItems, spacing: 4.0)),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 30.0)
            )
            if let domainView = self.domain.view {
                if domainView.superview == nil {
                    self.addSubview(domainView)
                }
                transition.setFrame(
                    view: domainView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - domainSize.width / 2.0), y: contentHeight),
                        size: domainSize
                    )
                )
            }
            contentHeight += domainSize.height
            contentHeight += 25.0

            let fiatCurrency = component.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = component.walletState?.fiat.selectedRate
            let amountNanograms = presentation.amountNanograms
            let amount = amountNanograms.flatMap { Int64($0) }
            let cardWidth = min(361.0, max(1.0, safeContentWidth - 42.0))
            self.card.parentState = state
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletTransferCardComponent(
                    amount: amount ?? 0,
                    recipient: presentation.recipient,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    amountText: amount == nil ? formatTonConnectNanograms(amountNanograms ?? "", strings: environment.strings, dateTimeFormat: environment.dateTimeFormat) : nil,
                    recipientTitle: presentation.recipientTitle(strings: environment.strings),
                    infoPressed: component.infoPressed
                )),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: availableSize.height)
            )
            if let cardView = self.card.view {
                if cardView.superview == nil {
                    self.addSubview(cardView)
                }
                cardView.clipsToBounds = true
                transition.setFrame(
                    view: cardView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - cardSize.width / 2.0), y: contentHeight),
                        size: cardSize
                    )
                )
            }
            contentHeight += cardSize.height
            contentHeight += 18.0

            let feeText = presentation.feeText(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)
            self.fee.parentState = state
            let feeSize = self.fee.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: feeText,
                        font: Font.regular(14.0),
                        textColor: secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: availableSize.height)
            )
            if let feeView = self.fee.view {
                if feeView.superview == nil {
                    self.addSubview(feeView)
                }
                transition.setFrame(
                    view: feeView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - feeSize.width / 2.0), y: contentHeight),
                        size: feeSize
                    )
                )
            }
            contentHeight += feeSize.height
            contentHeight += component.bottomInset

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
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

private final class WalletTransferActionsComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let confirmTitle: String
    let isBusy: Bool
    let isConfirming: Bool
    let cancel: () -> Void
    let confirm: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        confirmTitle: String,
        isBusy: Bool,
        isConfirming: Bool,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.confirmTitle = confirmTitle
        self.isBusy = isBusy
        self.isConfirming = isConfirming
        self.cancel = cancel
        self.confirm = confirm
    }

    static func ==(lhs: WalletTransferActionsComponent, rhs: WalletTransferActionsComponent) -> Bool {
        return lhs.theme == rhs.theme
            && lhs.strings === rhs.strings
            && lhs.confirmTitle == rhs.confirmTitle
            && lhs.isBusy == rhs.isBusy
            && lhs.isConfirming == rhs.isConfirming
    }

    final class View: UIView {
        private let cancelButton = ComponentView<Empty>()
        private let confirmButton = ComponentView<Empty>()

        private var component: WalletTransferActionsComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransferActionsComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let buttonSpacing: CGFloat = 10.0
            let height = min(52.0, availableSize.height)
            let cancelButtonWidth = floorToScreenPixels((availableSize.width - buttonSpacing) / 2.0)
            let confirmButtonWidth = availableSize.width - buttonSpacing - cancelButtonWidth

            let cancelSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: component.theme.list.itemPrimaryTextColor,
                        pressedColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "cancel",
                        component: AnyComponent(Text(
                            text: component.strings.Common_Cancel,
                            font: Font.semibold(17.0),
                            color: component.theme.list.itemPrimaryTextColor
                        ))
                    ),
                    isEnabled: !component.isBusy,
                    action: { [weak self] in
                        self?.component?.cancel()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: cancelButtonWidth, height: height)
            )
            if let cancelView = self.cancelButton.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                transition.setFrame(view: cancelView, frame: CGRect(origin: .zero, size: cancelSize))
            }

            let confirmSize = self.confirmButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "confirm",
                        component: AnyComponent(Text(
                            text: component.confirmTitle,
                            font: Font.semibold(17.0),
                            color: component.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: !component.isBusy,
                    displaysProgress: component.isConfirming,
                    action: { [weak self] in
                        self?.component?.confirm()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: confirmButtonWidth, height: height)
            )
            if let confirmView = self.confirmButton.view {
                if confirmView.superview == nil {
                    self.addSubview(confirmView)
                }
                transition.setFrame(
                    view: confirmView,
                    frame: CGRect(
                        origin: CGPoint(x: cancelButtonWidth + buttonSpacing, y: 0.0),
                        size: confirmSize
                    )
                )
            }

            return CGSize(width: availableSize.width, height: height)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletTransferSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectOperationRequest
    let confirm: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectOperationRequest,
        confirm: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.request = request
        self.confirm = confirm
    }

    static func ==(lhs: WalletTransferSheetComponent, rhs: WalletTransferSheetComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.request == rhs.request
    }

    final class State: ComponentState {
        private let disposables = DisposableSet()
        private var isFinished = false

        fileprivate let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        fileprivate var walletState: WalletContext.State?
        fileprivate var isAuthorizing = false
        fileprivate var isConfirming = false
        fileprivate var isPreviewPresented = false

        fileprivate var isBusy: Bool {
            return self.isAuthorizing || self.isConfirming
        }

        init(walletContext: WalletContext) {
            super.init()

            self.disposables.add((walletContext.state
            |> deliverOnMainQueue).start(next: { [weak self] walletState in
                guard let self, !self.isFinished else {
                    return
                }
                self.walletState = walletState
                self.updated(transition: .easeInOut(duration: 0.25))
            }))
        }

        deinit {
            self.disposables.dispose()
        }

        func finish(
            _ result: WalletTransferFinishResult,
            getController: () -> ViewController?,
            animated: Bool,
            animateOut: ActionSlot<Action<Void>>?
        ) {
            guard !self.isFinished, let controller = getController() as? WalletTransferScreen else {
                return
            }
            self.isFinished = true
            controller.finish(result, animated: animated, animateOut: animateOut)
        }

        func confirm(
            component: WalletTransferSheetComponent,
            getController: @escaping () -> ViewController?,
            animateOut: ActionSlot<Action<Void>>
        ) {
            guard !self.isFinished, !self.isAuthorizing, !self.isConfirming else {
                return
            }
            self.isAuthorizing = true
            self.updated(transition: .easeInOut(duration: 0.2))

            self.isAuthorizing = false
            self.isConfirming = true
            getController()?.view.isUserInteractionEnabled = false
            self.updated(transition: .easeInOut(duration: 0.2))
            component.confirm({ [weak self] result in
                Queue.mainQueue().async {
                    guard let self, !self.isFinished, let controller = getController() as? WalletTransferScreen, !controller.isDismissed else {
                        return
                    }
                    getController()?.view.isUserInteractionEnabled = true
                    switch result {
                    case .success:
                        self.finish(
                            .confirmed,
                            getController: getController,
                            animated: true,
                            animateOut: animateOut
                        )
                    case let .failure(error):
                        self.isConfirming = false
                        self.updated(transition: .easeInOut(duration: 0.2))
                        guard error != .authorizationCancelled else { return }
                        guard let controller = getController() else {
                            return
                        }
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(textAlertController(
                            context: component.context,
                            title: nil,
                            text: presentationData.strings.Wallet_Sign_Error,
                            actions: [
                                TextAlertAction(
                                    type: .defaultAction,
                                    title: presentationData.strings.Common_OK,
                                    action: {}
                                )
                            ]
                        ), in: .window(.root))
                    }
                }
            })
        }
    }

    func makeState() -> State {
        return State(walletContext: self.walletContext)
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)

        return { context in
            let component = context.component
            let componentState = context.state
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let theme = environment.theme.withModalBlocksBackground()
            let isSigning = WalletTransferPresentation(request: component.request, walletState: componentState.walletState).isSigning

            let dismiss: (Bool) -> Void = { [weak componentState] animated in
                componentState?.finish(
                    .cancelled,
                    getController: controller,
                    animated: animated,
                    animateOut: animated ? animateOut : nil
                )
            }

            let bottomInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let contentBottomInset = bottomInsets.bottom + 52.0 + 16.0

            let popPreview: () -> Void = { [weak componentState] in
                guard let componentState, componentState.isPreviewPresented else {
                    return
                }
                componentState.isPreviewPresented = false
                componentState.updated(transition: .spring(duration: 0.45))
            }

            var navigationItems: [AnyComponentWithIdentity<EnvironmentType>] = [
                AnyComponentWithIdentity(
                    id: "transfer",
                    component: AnyComponent(WalletTransferSheetContent(
                        context: component.context,
                        request: component.request,
                        walletState: componentState.walletState,
                        bottomInset: contentBottomInset,
                        infoPressed: { [weak componentState] in
                            guard let componentState, !isSigning, !componentState.isPreviewPresented else {
                                return
                            }
                            componentState.isPreviewPresented = true
                            componentState.updated(transition: .spring(duration: 0.45))
                        },
                        scrollViewUpdated: { [weak componentState] scrollView in
                            componentState?.sheetExternalState.setTrackedScrollView(scrollView)
                        }
                    ))
                )
            ]
            if componentState.isPreviewPresented && !isSigning {
                navigationItems.append(AnyComponentWithIdentity(
                    id: "preview",
                    component: AnyComponent(WalletTransferPreviewComponent(
                        context: component.context,
                        request: component.request,
                        walletState: componentState.walletState,
                        bottomInset: contentBottomInset
                    ))
                ))
            }

            let titleItem: AnyComponent<Empty>?
            let rightItem: AnyComponent<Empty>?
            if componentState.isPreviewPresented || isSigning {
                titleItem = AnyComponent(VStack<Empty>([
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: isSigning ? environment.strings.Wallet_Sign_SignData : environment.strings.Wallet_Sign_ConfirmAction,
                            font: Font.semibold(17.0),
                            color: theme.actionSheet.primaryTextColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "domain",
                        component: AnyComponent(Text(
                            text: component.request.domain,
                            font: Font.regular(13.0),
                            color: theme.actionSheet.secondaryTextColor
                        ))
                    )
                ], spacing: 0.0))
                rightItem = AnyComponent(WalletTransferNavigationAppIconComponent(
                    context: component.context,
                    applicationName: component.request.applicationName,
                    icon: component.request.icon
                ))
            } else {
                titleItem = nil
                rightItem = nil
            }

            let sheetComponent = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(NavigationStackComponent(
                        items: navigationItems,
                        clipContent: true,
                        requestPop: popPreview
                    )),
                    titleItem: titleItem,
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(
                            id: componentState.isPreviewPresented ? "back" : "close",
                            component: AnyComponent(BundleIconComponent(
                                name: componentState.isPreviewPresented ? "Navigation/Back" : "Navigation/Close",
                                tintColor: theme.chat.inputPanel.panelControlColor
                            ))
                        ),
                        action: { [weak componentState] _ in
                            guard let componentState else {
                                return
                            }
                            if componentState.isPreviewPresented {
                                popPreview()
                            } else if !componentState.isBusy {
                                dismiss(true)
                            }
                        }
                    )),
                    rightItem: rightItem,
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(WalletTransferActionsComponent(
                        theme: theme,
                        strings: environment.strings,
                        confirmTitle: isSigning ? environment.strings.Wallet_Sign_Sign : environment.strings.Wallet_Sign_Confirm,
                        isBusy: componentState.isBusy,
                        isConfirming: componentState.isConfirming,
                        cancel: {
                            dismiss(true)
                        },
                        confirm: { [weak componentState] in
                            componentState?.confirm(
                                component: component,
                                getController: controller,
                                animateOut: animateOut
                            )
                        }
                    )),
                    backgroundColor: .color(theme.list.plainBackgroundColor),
                    clipsContent: true,
                    externalState: componentState.sheetExternalState,
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

public final class WalletTransferScreen: ViewControllerComponentContainer {
    private let cancelled: () -> Void
    public var tonConnectClosed: (() -> Void)?
    private var finishResult: WalletTransferFinishResult?
    fileprivate var isDismissed = false

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.isDismissed = true
        super.dismiss(animated: flag, completion: completion)
    }

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectOperationRequest,
        cancelled: @escaping () -> Void,
        confirm: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.cancelled = cancelled

        super.init(
            context: context,
            component: WalletTransferSheetComponent(
                context: context,
                walletContext: walletContext,
                request: request,
                confirm: confirm
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    fileprivate func finish(
        _ result: WalletTransferFinishResult,
        animated: Bool,
        animateOut: ActionSlot<Action<Void>>?
    ) {
        guard self.finishResult == nil else {
            return
        }
        self.finishResult = result

        let callback: () -> Void
        switch result {
        case .cancelled:
            callback = self.cancelled
        case .confirmed:
            callback = {}
        }

        let dismissController: () -> Void = { [weak self] in
            guard let self else {
                callback()
                return
            }
            self.dismiss(completion: {
                callback()
                self.tonConnectClosed?()
            })
        }
        if animated, let animateOut {
            animateOut.invoke(Action { _ in
                dismissController()
            })
        } else if animated {
            dismissController()
        } else {
            self.dismiss(animated: false, completion: {
                callback()
                self.tonConnectClosed?()
            })
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.finish(.cancelled, animated: false, animateOut: nil)
        }
    }
}
