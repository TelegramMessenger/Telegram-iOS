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
import ListSectionComponent
import Markdown
import TelegramUIPreferences
import ListMultilineTextFieldItemComponent
import TextFieldComponent
import ListActionItemComponent
import CheckComponent
import PlainButtonComponent
import EntityKeyboard
import EmojiStatusComponent

final class TextStyleEditContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class ExternalState {
        let titleInputState = ListMultilineTextFieldItemComponent.ExternalState()
        let textInputState = ListMultilineTextFieldItemComponent.ExternalState()
        var isLinkToProfileEnabled: Bool = false
        var emojiFile: TelegramMediaFile?
    }
    
    let externalState: ExternalState
    let context: AccountContext
    let mode: TextStyleEditScreen.Mode
    let styleDeleted: () -> Void

    init(
        externalState: ExternalState,
        context: AccountContext,
        mode: TextStyleEditScreen.Mode,
        styleDeleted: @escaping () -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.mode = mode
        self.styleDeleted = styleDeleted
    }

    static func ==(lhs: TextStyleEditContentComponent, rhs: TextStyleEditContentComponent) -> Bool {
        return true
    }
    
    private enum Mode {
        case translate
        case stylize
        case fix
    }

    final class View: UIView {
        private var component: TextStyleEditContentComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var previousEnvironment: ViewControllerComponentContainer.Environment?
        
        private let iconBackground = ComponentView<Empty>()
        private let emptyIcon = ComponentView<Empty>()
        private var emojiIcon: ComponentView<Empty>?
        private let titleSection = ComponentView<Empty>()
        private let textSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()
        private let linkOption = ComponentView<Empty>()

        private let titleFieldTag = ListMultilineTextFieldItemComponent.Tag()
        private let textFieldTag = ListMultilineTextFieldItemComponent.Tag()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        private func recenterCaret(hintView: UIView, transition: ComponentTransition) {
            var fieldView: ListMultilineTextFieldItemComponent.View?
            var ancestor: UIView? = hintView
            while let current = ancestor {
                if let candidate = current as? ListMultilineTextFieldItemComponent.View {
                    fieldView = candidate
                    break
                }
                ancestor = current.superview
            }
            guard let fieldView else {
                return
            }
            if !(fieldView.matches(tag: self.titleFieldTag) || fieldView.matches(tag: self.textFieldTag)) {
                return
            }
            guard let inputTextView = fieldView.textFieldView?.inputTextView else {
                return
            }
            let caretPosition = inputTextView.selectedTextRange?.end ?? inputTextView.endOfDocument
            let caretRect = inputTextView.caretRect(for: caretPosition)
            if caretRect.isNull || caretRect.isInfinite {
                return
            }

            var scrollAncestor: UIView? = self.superview
            var scrollView: UIScrollView?
            while let current = scrollAncestor {
                if let candidate = current as? UIScrollView {
                    scrollView = candidate
                    break
                }
                scrollAncestor = current.superview
            }
            guard let scrollView, let environment = self.environment else {
                return
            }

            let caretInScroll = inputTextView.convert(caretRect, to: scrollView)

            // ResizableSheetComponent bottom action button (52pt) + gap above it (8pt).
            let bottomActionAreaHeight: CGFloat = 60.0
            let caretTopInset: CGFloat = 24.0
            let caretBottomInset: CGFloat = 24.0
            let visibleTop = scrollView.bounds.minY + caretTopInset
            let visibleBottom = scrollView.bounds.maxY - environment.inputHeight - bottomActionAreaHeight - caretBottomInset

            let previousBounds = scrollView.bounds
            var newBounds = previousBounds
            if caretInScroll.maxY > visibleBottom {
                newBounds.origin.y += (caretInScroll.maxY - visibleBottom)
            } else if caretInScroll.minY < visibleTop {
                newBounds.origin.y -= (visibleTop - caretInScroll.minY)
            }
            let maxOriginY = max(0.0, scrollView.contentSize.height - scrollView.bounds.height)
            newBounds.origin.y = min(max(0.0, newBounds.origin.y), maxOriginY)

            if newBounds != previousBounds {
                scrollView.bounds = newBounds
                if !transition.animation.isImmediate {
                    let offsetY = previousBounds.origin.y - newBounds.origin.y
                    transition.animateBoundsOrigin(view: scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
        }
        
        func activateEmojiSelection() {
            guard let component = self.component else {
                return
            }
            guard let iconBackgroundView = self.iconBackground.view else {
                return
            }
            self.environment?.controller()?.present(component.context.sharedContext.makeEmojiStatusSelectionController(
                context: component.context,
                mode: .backgroundSelection(completion: { [weak self] file in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.externalState.emojiFile = file
                    self.state?.updated(transition: .immediate)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }
                        self.state?.updated(transition: .immediate)
                    }
                }),
                sourceView: iconBackgroundView,
                emojiContent: EmojiPagerContentComponent.emojiInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    isStandalone: false,
                    subject: .emoji,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: component.context.account.peerId,
                    selectedItems: Set()
                ) |> map { $0 },
                currentSelection: nil,
                color: nil,
                destinationItemView: { [weak self] in
                    guard let self else {
                        return nil
                    }
                    return self.emojiIcon?.view
                }
            ), in: .window(.root))
        }

        func update(component: TextStyleEditContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let previousEnvironment = self.previousEnvironment
            self.previousEnvironment = environment
            
            var resetTitle: String?
            var resetText: String?
            if self.component == nil {
                resetTitle = ""
                if case let .edit(style) = component.mode, case let .custom(style) = style.content {
                    resetTitle = style.title
                    resetText = style.prompt ?? ""
                    component.externalState.isLinkToProfileEnabled = style.authorId != nil
                }
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            let sideInset: CGFloat = 16.0
            let sectionSpacing: CGFloat = 24.0
            let iconSpacing: CGFloat = 24.0

            var contentHeight: CGFloat = 0.0
            contentHeight += 70.0
            
            let iconBackgroundSize = CGSize(width: 100.0, height: 100.0)
            let _ = self.iconBackground.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(FilledRoundedRectangleComponent(
                        color: environment.theme.list.itemBlocksBackgroundColor,
                        cornerRadius: .minEdge,
                        smoothCorners: false
                    )),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.activateEmojiSelection()
                    },
                    animateAlpha: false,
                    animateScale: false,
                )),
                environment: {},
                containerSize: iconBackgroundSize
            )
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconBackgroundSize.width) * 0.5), y: contentHeight), size: iconBackgroundSize)
            if let iconBackgroundView = self.iconBackground.view {
                if iconBackgroundView.superview == nil {
                    self.addSubview(iconBackgroundView)
                }
                transition.setFrame(view: iconBackgroundView, frame: iconBackgroundFrame)
            }
            
            let emptyIconSize = self.emptyIcon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "TextProcessing/EditEmojiPlaceholder",
                    tintColor: environment.theme.list.controlSecondaryColor
                )),
                environment: {},
                containerSize: iconBackgroundFrame.size
            )
            let emptyIconFrame = emptyIconSize.centered(in: iconBackgroundFrame)
            if let emptyIconView = self.emptyIcon.view {
                if emptyIconView.superview == nil {
                    self.addSubview(emptyIconView)
                    emptyIconView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: emptyIconView, frame: emptyIconFrame)
                transition.setAlpha(view: emptyIconView, alpha: component.externalState.emojiFile == nil ? 1.0 : 0.0)
            }
            
            if let emojiFile = component.externalState.emojiFile {
                var emojiIconTransition = transition
                let emojiIcon: ComponentView<Empty>
                if let current = self.emojiIcon {
                    emojiIcon = current
                } else {
                    emojiIconTransition = emojiIconTransition.withAnimation(.none)
                    emojiIcon = ComponentView()
                    self.emojiIcon = emojiIcon
                }
                let emojiSize = CGSize(width: 70.0, height: 70.0)
                let emojiIconSize = emojiIcon.update(
                    transition: emojiIconTransition,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .animation(
                            content: .file(file: emojiFile),
                            size: emojiSize,
                            placeholderColor: environment.theme.list.mediaPlaceholderColor,
                            themeColor: environment.theme.list.itemPrimaryTextColor,
                            loopMode: .count(1)
                        ),
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: emojiSize
                )
                let emojiIconFrame = emojiIconSize.centered(in: iconBackgroundFrame)
                if let emojiIconView = emojiIcon.view {
                    if emojiIconView.superview == nil {
                        self.addSubview(emojiIconView)
                        emojiIconView.isUserInteractionEnabled = false
                    }
                    emojiIconTransition.setFrame(view: emojiIconView, frame: emojiIconFrame)
                }
            } else {
                if let emojiIcon = self.emojiIcon {
                    self.emojiIcon = nil
                    if let emojiIconView = emojiIcon.view {
                        transition.setAlpha(view: emojiIconView, alpha: 0.0, completion: { [weak emojiIconView] _ in
                            emojiIconView?.removeFromSuperview()
                        })
                        transition.setScale(view: emojiIconView, scale: 0.001)
                    }
                }
            }
            
            contentHeight += iconBackgroundSize.height + iconSpacing
            
            var titleSectionItems: [AnyComponentWithIdentity<Empty>] = []
            titleSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: component.externalState.titleInputState,
                style: .glass,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: resetTitle.flatMap { resetTitle in
                    return ListMultilineTextFieldItemComponent.ResetText(value: resetTitle)
                },
                placeholder: environment.strings.TextProcessing_EditStyle_NamePlaceholder,
                autocapitalizationType: .sentences,
                autocorrectionType: .default,
                characterLimit: 12,
                emptyLineHandling: .notAllowed,
                updated: nil,
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.titleFieldTag
            ))))
            let titleSectionSize = self.titleSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: titleSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let titleSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: titleSectionSize)
            if let titleSectionView = self.titleSection.view {
                if titleSectionView.superview == nil {
                    self.addSubview(titleSectionView)
                    self.titleSection.parentState = state
                }
                transition.setFrame(view: titleSectionView, frame: titleSectionFrame)
            }
            contentHeight += titleSectionSize.height
            contentHeight += sectionSpacing
            
            var textSectionItems: [AnyComponentWithIdentity<Empty>] = []
            textSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: component.externalState.textInputState,
                style: .glass,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: resetText.flatMap { resetText in
                    return ListMultilineTextFieldItemComponent.ResetText(value: resetText)
                },
                placeholder: environment.strings.TextProcessing_EditStyle_TextPlaceholder,
                placeholderDefinesMinHeight: true,
                autocapitalizationType: .sentences,
                autocorrectionType: .default,
                characterLimit: 1024,
                emptyLineHandling: .allowed,
                updated: nil,
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.textFieldTag
            ))))
            let textSectionSize = self.textSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: textSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let textSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: textSectionSize)
            if let textSectionView = self.textSection.view {
                if textSectionView.superview == nil {
                    self.addSubview(textSectionView)
                    self.textSection.parentState = state
                }
                transition.setFrame(view: textSectionView, frame: textSectionFrame)
            }
            contentHeight += textSectionSize.height
            
            if case let .edit(style) = component.mode, case let .custom(style) = style.content {
                contentHeight += sectionSpacing
                
                let deleteSectionSize = self.deleteSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            style: .glass,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.TextProcessing_EditStyle_Delete,
                                        font: Font.regular(17.0),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .center, spacing: 2.0, fillWidth: true)),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                environment.controller()?.push(textAlertController(
                                    context: component.context,
                                    title: environment.strings.TextProcessing_AlertCreatorDeleteStyle_Title,
                                    text: environment.strings.TextProcessing_AlertCreatorDeleteStyle_Text,
                                    actions: [
                                        TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                                        TextAlertAction(type: .destructiveAction, title: environment.strings.Common_Delete, action: { [weak self] in
                                            guard let self, let component = self.component else {
                                                return
                                            }
                                            let _ = component.context.engine.messages.deleteAITextStyle(id: style.id, accessHash: style.accessHash).startStandalone()
                                            component.styleDeleted()
                                        }),
                                    ]
                                ))
                            }
                        )))]
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let deleteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: deleteSectionSize)
                if let deleteSectionView = self.deleteSection.view {
                    if deleteSectionView.superview == nil {
                        self.addSubview(deleteSectionView)
                        self.deleteSection.parentState = state
                    }
                    transition.setFrame(view: deleteSectionView, frame: deleteSectionFrame)
                }
                contentHeight += deleteSectionSize.height
            }
            
            contentHeight += 23.0
            
            let checkTheme = CheckComponent.Theme(
                backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                strokeColor: environment.theme.list.itemCheckColors.foregroundColor,
                borderColor: environment.theme.list.itemCheckColors.strokeColor,
                overlayBorder: false,
                hasInset: false,
                hasShadow: false
            )
            let linkOptionSize = self.linkOption.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                            theme: checkTheme,
                            size: CGSize(width: 18.0, height: 18.0),
                            selected: component.externalState.isLinkToProfileEnabled
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.TextProcessing_EditStyle_AddLink, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor))
                        )))
                    ], spacing: 10.0)),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        component.externalState.isLinkToProfileEnabled = !component.externalState.isLinkToProfileEnabled
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    animateAlpha: false,
                    animateScale: false
                )),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let linkOptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - linkOptionSize.width) * 0.5), y: contentHeight), size: linkOptionSize)
            if let linkOptionView = self.linkOption.view {
                if linkOptionView.superview == nil {
                    self.addSubview(linkOptionView)
                }
                transition.setFrame(view: linkOptionView, frame: linkOptionFrame)
            }
            contentHeight += linkOptionSize.height
            
            contentHeight += 104.0

            let _ = alphaTransition

            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let hintView = hint.view {
                switch hint.kind {
                case .textChanged:
                    self.recenterCaret(hintView: hintView, transition: transition)
                default:
                    break
                }
            }
            if let previousEnvironment {
                var targetView: UIView?
                if component.externalState.titleInputState.isEditing {
                    if let view = self.titleSection.findTaggedView(tag: self.titleFieldTag) as? ListMultilineTextFieldItemComponent.View {
                        targetView = view
                    }
                } else if component.externalState.textInputState.isEditing {
                    if let view = self.textSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View {
                        targetView = view
                    }
                }
                
                if let targetView {
                    if (environment.inputHeight == 0.0) != (previousEnvironment.inputHeight == 0.0) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }
                            self.recenterCaret(hintView: targetView, transition: transition)
                        }
                    }
                }
            }

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

private final class TextStyleEditSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: TextStyleEditScreen.Mode
    let initialEmojiFile: TelegramMediaFile?
    let completion: (TelegramComposeAIMessageMode.CloudStyle) -> Void
    let styleDeleted: () -> Void

    init(
        context: AccountContext,
        mode: TextStyleEditScreen.Mode,
        initialEmojiFile: TelegramMediaFile?,
        completion: @escaping (TelegramComposeAIMessageMode.CloudStyle) -> Void,
        styleDeleted: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.initialEmojiFile = initialEmojiFile
        self.completion = completion
        self.styleDeleted = styleDeleted
    }

    static func ==(lhs: TextStyleEditSheetComponent, rhs: TextStyleEditSheetComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: TextStyleEditSheetComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let contentState = TextStyleEditContentComponent.ExternalState()
        
        private var isActionInProgress: Bool = false
        private var createDisposable: Disposable?

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.contentState.titleInputState.updated = { [weak self] in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            }
            self.contentState.textInputState.updated = self.contentState.titleInputState.updated
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.createDisposable?.dispose()
        }
        
        private func performCreateStyle() {
            guard let component = self.component else {
                return
            }
            if self.contentState.titleInputState.text.string.isEmpty || self.contentState.textInputState.text.string.isEmpty {
                return
            }
            guard let emojiFile = self.contentState.emojiFile else {
                if let sheetView = self.sheet.view as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                    if let contentView = sheetView.contentViewValue as? TextStyleEditContentComponent.View {
                        contentView.activateEmojiSelection()
                    }
                }
                return
            }
            
            self.createDisposable?.dispose()
            
            switch component.mode {
            case .create:
                self.isActionInProgress = true
                if !self.isUpdating {
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
                
                self.createDisposable = (component.context.engine.messages.createAITextStyle(
                    displayAuthor: self.contentState.isLinkToProfileEnabled,
                    emojiFileId: emojiFile.fileId.id,
                    title: self.contentState.titleInputState.text.string,
                    prompt: self.contentState.textInputState.text.string
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let controller = environment.controller
                    
                    self.animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                    
                    component.completion(result)
                }, error: { [weak self] error in
                    guard let self else {
                        return
                    }
                    
                    self.isActionInProgress = false
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                })
            case let .edit(style):
                guard case let .custom(style) = style.content else {
                    return
                }
                self.isActionInProgress = true
                if !self.isUpdating {
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
                self.createDisposable = (component.context.engine.messages.editAITextStyle(
                    id: style.id,
                    accessHash: style.accessHash,
                    displayAuthor: self.contentState.isLinkToProfileEnabled,
                    emojiFileId: emojiFile.fileId.id,
                    title: self.contentState.titleInputState.text.string,
                    prompt: self.contentState.textInputState.text.string
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let controller = environment.controller
                    
                    self.animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                    
                    component.completion(result)
                }, error: { [weak self] error in
                    guard let self else {
                        return
                    }
                    
                    self.isActionInProgress = false
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                })
            }
        }

        func update(component: TextStyleEditSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                self.contentState.emojiFile = component.initialEmojiFile
            }
            
            self.component = component
            self.state = state

            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme

            let dismiss: (Bool) -> Void = { [weak self] animated in
                if animated {
                    self?.animateOut.invoke(Action { _ in
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

            let performMainAction: () -> Void = { [weak self] in
                guard let self else {
                    return
                }
                self.performCreateStyle()
            }
            let isMainActionEnabled = !self.contentState.titleInputState.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !self.contentState.textInputState.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !self.isActionInProgress
            let actionButtonTitle: String
            let titleString: String
            switch component.mode {
            case .create:
                titleString = environmentValue.strings.TextProcessing_EditStyle_TitleCreate
                actionButtonTitle = environmentValue.strings.TextProcessing_EditStyle_ActionCreate
            case .edit:
                titleString = environmentValue.strings.TextProcessing_EditStyle_TitleEdit
                actionButtonTitle = environmentValue.strings.TextProcessing_EditStyle_ActionEdit
            }

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(TextStyleEditContentComponent(
                        externalState: self.contentState,
                        context: component.context,
                        mode: component.mode,
                        styleDeleted: component.styleDeleted
                    )),
                    titleItem: AnyComponent(TitleComponent(
                        theme: theme,
                        title: titleString
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
                    rightItem: nil,
                    bottomItem: AnyComponent(
                        ActionButtonsComponent(
                            theme: theme,
                            strings: environmentValue.strings,
                            actionTitle: actionButtonTitle,
                            displayProgress: self.isActionInProgress,
                            action: isMainActionEnabled ? performMainAction : nil
                        )
                    ),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environmentValue
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environmentValue.statusBarHeight,
                        safeInsets: environmentValue.safeInsets,
                        inputHeight: environmentValue.inputHeight,
                        metrics: environmentValue.metrics,
                        deviceMetrics: environmentValue.deviceMetrics,
                        isDisplaying: environmentValue.isVisible,
                        isCentered: environmentValue.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
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

public class TextStyleEditScreen: ViewControllerComponentContainer {
    public enum Mode {
        case create
        case edit(TelegramComposeAIMessageMode.CloudStyle)
    }
    
    private let context: AccountContext

    public init(
        context: AccountContext,
        theme: PresentationTheme? = nil,
        mode: Mode,
        completion: @escaping (TelegramComposeAIMessageMode.CloudStyle) -> Void,
        styleDeleted: @escaping () -> Void
    ) async {
        self.context = context
        
        var initialEmojiFile: TelegramMediaFile?
        if case let .edit(style) = mode, case let .custom(style) = style.content, let emojiFileId = style.emojiFileId {
            initialEmojiFile = await context.engine.stickers.resolveInlineStickersLocal(fileIds: [emojiFileId]).get()[emojiFileId]
        }
        
        super.init(
            context: context,
            component: TextStyleEditSheetComponent(
                context: context,
                mode: mode,
                initialEmojiFile: initialEmojiFile,
                completion: completion,
                styleDeleted: styleDeleted
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: theme.flatMap({ .custom($0) }) ?? .default
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
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: TitleComponent, rhs: TitleComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
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

private final class ActionButtonsComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let actionTitle: String
    let displayProgress: Bool
    let action: (() -> Void)?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        actionTitle: String,
        displayProgress: Bool,
        action: (() -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.displayProgress = displayProgress
        self.action = action
    }
    
    static func ==(lhs: ActionButtonsComponent, rhs: ActionButtonsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        if lhs.displayProgress != rhs.displayProgress {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let actionButton = ComponentView<Empty>()

        private var component: ActionButtonsComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ActionButtonsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let actionButtonWidth: CGFloat = availableSize.width
            
            var actionButtonContents: [AnyComponentWithIdentity<Empty>] = []
            actionButtonContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: component.actionTitle, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor))
            ))))
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(HStack(
                            actionButtonContents,
                            spacing: 6.0
                        ))
                    ),
                    isEnabled: component.action != nil,
                    displaysProgress: component.displayProgress,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonWidth, height: availableSize.height)
            )
            let actionButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }

            return CGSize(width: availableSize.width, height: actionButtonSize.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
