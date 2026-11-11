import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import ViewControllerComponent
import ResizableSheetComponent
import ListSectionComponent
import ListTextFieldItemComponent
import MultilineTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import TelegramPresentationData
import TelegramCore
import LocalizedPeerData
import InstantPageUI
import RichTextEditorCore
import RichTextEditorMessageConversion

private let buttonLabelInputTag = GenericComponentViewTag()
private let buttonURLInputTag = GenericComponentViewTag()
private let buttonCopyTextInputTag = GenericComponentViewTag()

/// The property sheet for ONE InstantPage button, for both pill kinds. Modelled on
/// `FormulaEditorScreen` — same sheet host, same list-section idiom, same live preview approach.
///
/// `.url`, `.copyText` and `.userProfile` are creatable (`ButtonActionChoice`): a callback / web-app /
/// payment button is a bot affordance a user-composed message has nothing to bind to. Such an action
/// arrives only via the edit round-trip and is shown read-only, its opaque payload passing through
/// untouched — see `ButtonAction.unsupported`.

// MARK: - Action

/// The action kinds the sheet authors. A profile button names a USER only: the schema has no chat or
/// channel profile type (`inlineButtonTypeUserProfile` carries a `user_id`); a chat is reached through a
/// URL button with its t.me link.
private enum ButtonActionChoice: CaseIterable {
    case url
    case copyText
    case userProfile

    /// `nil` for an action the sheet cannot author (disabled, or preserved from an incoming message):
    /// the section then shows no selected row until the author picks one.
    static func from(_ action: ButtonAction) -> ButtonActionChoice? {
        switch action {
        case .url: return .url
        case .copyText: return .copyText
        case .userProfile: return .userProfile
        case .disabled, .unsupported: return nil
        }
    }

    func title(_ strings: PresentationStrings) -> String {
        switch self {
        case .url: return strings.RichText_ButtonActionTypeURL
        case .copyText: return strings.RichText_ButtonActionTypeCopy
        case .userProfile: return strings.RichText_ButtonActionTypeUserProfile
        }
    }
}

// MARK: - Style

/// The choices offered. `link` is deliberately NOT a fourth colour: it is a separate bit in the
/// schema (`richButtonStyle.link`), and selecting it PRESERVES whatever colour the button already had,
/// so an incoming `link + danger` still round-trips. The renderer makes link win either way.
///
/// **`link` is offered for an INLINE pill only** — see `choices(isBlockPill:)`.
private enum ButtonStyleChoice: CaseIterable {
    case `default`
    case primary
    case danger
    case success
    case link

    /// The styles authorable for this pill kind. A BLOCK-row pill drops `link`: a link-styled row button
    /// renders chrome-less (no fill, plain link colour — `instantPageButtonColors`), which is a shape an
    /// author has no reason to create for a standalone row. Inline it is the whole point of the style —
    /// the pill becomes plain link text in the flow — so the inline sheet keeps it.
    ///
    /// This does NOT strip `isLink` from a button that already carries it (one that arrived through the
    /// edit round-trip): the bit is only ever cleared by picking another style, so an untouched incoming
    /// link row button round-trips unchanged. Its style section simply shows no selected row.
    static func choices(isBlockPill: Bool) -> [ButtonStyleChoice] {
        isBlockPill ? allCases.filter { $0 != .link } : allCases
    }

    static func from(_ button: ButtonRef) -> ButtonStyleChoice {
        if button.isLink {
            return .link
        }
        switch button.color {
        case .none: return .default
        case .some(.primary): return .primary
        case .some(.danger): return .danger
        case .some(.success): return .success
        }
    }

    /// Applies the choice, PRESERVING the underlying colour when `link` is chosen.
    func apply(to button: ButtonRef) -> ButtonRef {
        var result = button
        switch self {
        case .default:
            result.color = nil
            result.isLink = false
        case .primary:
            result.color = .primary
            result.isLink = false
        case .danger:
            result.color = .danger
            result.isLink = false
        case .success:
            result.color = .success
            result.isLink = false
        case .link:
            result.isLink = true   // `color` intentionally untouched
        }
        return result
    }

    func title(_ strings: PresentationStrings) -> String {
        switch self {
        case .default: return strings.RichText_ButtonStyleDefault
        case .primary: return strings.RichText_ButtonStylePrimary
        case .danger: return strings.RichText_ButtonStyleDanger
        case .success: return strings.RichText_ButtonStyleSuccess
        case .link: return strings.RichText_ButtonStyleLink
        }
    }
}

/// A human-readable description of an action the editor cannot author, shown read-only.
private func preservedActionDescription(_ action: ButtonAction, _ strings: PresentationStrings) -> String? {
    switch action {
    case .url, .copyText, .userProfile:
        return nil
    case .disabled:
        return strings.RichText_ButtonActionDisabled
    case .unsupported:
        return strings.RichText_ButtonActionNotEditable
    }
}

// MARK: - Preview

/// A REAL V2 pill: builds a one-block `InstantPage` carrying the edited button and renders it through
/// `InstantPageV2View`, exactly as `FormulaPreviewItemComponent` does for a formula. Nothing here is a
/// mock, so what the author sees is what the recipient gets.
private final class ButtonPreviewItemComponent: Component {
    typealias EnvironmentType = Empty

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let button: ButtonRef

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, button: ButtonRef) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.button = button
    }

    static func ==(lhs: ButtonPreviewItemComponent, rhs: ButtonPreviewItemComponent) -> Bool {
        if lhs.context !== rhs.context { return false }
        if lhs.theme !== rhs.theme { return false }
        if lhs.button != rhs.button { return false }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private let pageView: InstantPageV2View
        private var component: ButtonPreviewItemComponent?

        var customUpdateIsHighlighted: ((Bool) -> Void)?
        var enumerateSiblings: (((UIView) -> Void) -> Void)?
        let separatorInset: CGFloat = 0.0

        override init(frame: CGRect) {
            self.pageView = InstantPageV2View(renderContext: nil)
            super.init(frame: frame)
            self.addSubview(self.pageView)
        }

        required init?(coder: NSCoder) { preconditionFailure() }

        func update(component: ButtonPreviewItemComponent, availableSize: CGSize, state: EmptyComponentState,
                    environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let sideInset: CGFloat = 16.0
            let innerWidth = max(1.0, availableSize.width - sideInset * 2.0)
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let pageTheme = buttonInstantPageTheme(presentationTheme: component.theme)

            // The label falls back to a placeholder so an unnamed button still previews as a pill.
            let label = component.button.labelText.isEmpty
                ? component.strings.RichText_ButtonLabelPlaceholder
                : component.button.labelText
            let page = InstantPage(
                blocks: [.buttonRow(alignment: .center, buttons: [InstantPageButton(
                    text: .plain(label),
                    action: replyMarkupButtonAction(from: component.button.action),
                    color: replyMarkupColor(from: component.button.color),
                    isLink: component.button.isLink
                )])],
                media: [:], isComplete: true, rtl: false, url: "", views: nil
            )
            // `layoutInstantPageV2` takes a non-optional webpage; wrap the page exactly as the formula
            // preview does. Nothing reads the wrapper's fields for a button row.
            let webpage = TelegramMediaWebpage(
                webpageId: EngineMedia.Id(namespace: 0, id: 0),
                content: .Loaded(TelegramMediaWebpageLoadedContent(
                    url: "", displayUrl: "", hash: 0, type: nil, websiteName: nil, title: nil, text: nil,
                    embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil,
                    isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil,
                    story: nil, attributes: [], instantPage: page
                ))
            )
            let layout = layoutInstantPageV2(
                webpage: webpage,
                instantPage: page,
                userLocation: .other,
                boundingWidth: innerWidth,
                horizontalInset: 0.0,
                theme: pageTheme,
                strings: component.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                cachedMessageSyntaxHighlight: nil,
                expandedDetails: [:],
                fitToWidth: true,
                // This previews the bubble, which follows Text Size — so must the preview.
                contentScale: instantPageChatMessageContentScale(baseFontSize: presentationData.chatFontSize.baseDisplaySize)
            )
            self.pageView.update(layout: layout, theme: pageTheme, animation: .None)

            let previewSize = CGSize(width: max(1.0, layout.contentSize.width), height: layout.contentSize.height)
            let contentHeight: CGFloat = 84.0
            transition.setFrame(view: self.pageView, frame: CGRect(
                origin: CGPoint(x: sideInset + floorToScreenPixels((innerWidth - previewSize.width) * 0.5),
                                y: floorToScreenPixels((contentHeight - previewSize.height) * 0.5)),
                size: previewSize
            ))
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View { View(frame: CGRect()) }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState,
                environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

/// Mirrors `formulaInstantPageTheme`. The pill colours come from the presentation theme so the preview
/// matches the sheet it sits in.
private func buttonInstantPageTheme(presentationTheme: PresentationTheme) -> InstantPageTheme {
    let textColor = presentationTheme.list.itemPrimaryTextColor
    let paragraph = InstantPageTextAttributes(
        font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0),
        color: textColor
    )
    let categories = InstantPageTextCategories(
        kicker: paragraph, header: paragraph, subheader: paragraph, paragraph: paragraph,
        caption: paragraph, credit: paragraph, table: paragraph, article: paragraph, codeBlock: paragraph
    )
    return InstantPageTheme(
        type: presentationTheme.overallDarkAppearance ? .dark : .light,
        pageBackgroundColor: .clear,
        textCategories: categories,
        serif: false,
        codeBlockBackgroundColor: .clear,
        linkColor: presentationTheme.list.itemAccentColor,
        textHighlightColor: presentationTheme.list.itemAccentColor.withMultipliedAlpha(0.2),
        linkHighlightColor: presentationTheme.list.itemAccentColor.withMultipliedAlpha(0.2),
        markerColor: presentationTheme.list.itemAccentColor,
        panelBackgroundColor: presentationTheme.list.itemPrimaryTextColor.withMultipliedAlpha(0.08),
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

// MARK: - Sheet content

private final class ButtonEditorSheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let button: ButtonRef
    /// Which pill kind is being edited — it selects the authorable style set (see `choices(isBlockPill:)`).
    let isBlockPill: Bool
    /// The user a `.userProfile` action names, once resolved; `nil` shows the "Choose User" prompt.
    let profilePeer: EnginePeer?
    let update: (ButtonRef) -> Void
    /// Opens the user picker; the choice comes back through `update` as a `.userProfile` action.
    let chooseUser: () -> Void
    let complete: (ButtonRef?) -> Void

    init(context: AccountContext, button: ButtonRef, isBlockPill: Bool, profilePeer: EnginePeer?,
         update: @escaping (ButtonRef) -> Void, chooseUser: @escaping () -> Void,
         complete: @escaping (ButtonRef?) -> Void) {
        self.context = context
        self.button = button
        self.isBlockPill = isBlockPill
        self.profilePeer = profilePeer
        self.update = update
        self.chooseUser = chooseUser
        self.complete = complete
    }

    static func ==(lhs: ButtonEditorSheetContent, rhs: ButtonEditorSheetContent) -> Bool {
        if lhs.context !== rhs.context { return false }
        if lhs.button != rhs.button { return false }
        if lhs.isBlockPill != rhs.isBlockPill { return false }
        if lhs.profilePeer != rhs.profilePeer { return false }
        return true
    }

    final class View: UIView {
        private let previewSection = ComponentView<Empty>()
        private let fieldsSection = ComponentView<Empty>()
        private let actionSection = ComponentView<Empty>()
        private let styleSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()

        private var component: ButtonEditorSheetContent?

        override init(frame: CGRect) { super.init(frame: frame) }
        required init?(coder: NSCoder) { preconditionFailure() }

        func update(component: ButtonEditorSheetContent, availableSize: CGSize, state: EmptyComponentState,
                    environment: Environment<ViewControllerComponentContainer.Environment>,
                    transition: ComponentTransition) -> CGSize {
            self.component = component
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: availableSize.width, height: 0.0)
            // TOP NAVIGATION INSET. `ResizableSheetComponent` hosts `titleItem` / `leftItem` /
            // `rightItem` in a `navigationBarContainer` that OVERLAYS the content (with a top edge
            // effect), so the content must reserve room for it or the first section slides underneath.
            // 82pt is what `TextProcessingScreen` reserves; the title is centred at y=38 in a ~76pt bar.
            contentSize.height += 82.0

            let headerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let sectionWidth = availableSize.width - sideInset * 2.0

            // Live preview — a real V2 pill.
            let previewSize = self.previewSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass, header: nil, footer: nil,
                    items: [AnyComponentWithIdentity(id: "preview", component: AnyComponent(
                        ButtonPreviewItemComponent(context: component.context, theme: theme,
                                                   strings: strings, button: component.button)
                    ))],
                    displaySeparators: false
                )),
                environment: {}, containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let view = self.previewSection.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentSize.height), size: previewSize))
            }
            contentSize.height += previewSize.height + 24.0

            // Label, and the action's payload when the action is editable: a URL, the text to copy, or the
            // user. Each payload field has its own id, so switching the action type starts a fresh field.
            var fieldItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "label", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass, theme: theme,
                    initialText: component.button.labelText,
                    placeholder: strings.RichText_ButtonLabelPlaceholder,
                    clearButtonAccessibilityLabel: strings.WebSearch_RecentSectionClear,
                    hasClearButton: true,
                    updated: { [weak self] text in
                        guard let self, let component = self.component else { return }
                        var updated = component.button
                        // A rich incoming label flattens to plain text once edited — an accepted
                        // limitation: the field edits a String, and preserving per-run formatting
                        // through an arbitrary edit is not representable here.
                        updated.label = text.isEmpty ? [] : [TextRun(text: text)]
                        component.update(updated)
                    },
                    tag: buttonLabelInputTag
                )))
            ]
            switch component.button.action {
            case let .url(url):
                fieldItems.append(AnyComponentWithIdentity(id: "url", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass, theme: theme,
                    initialText: url,
                    placeholder: strings.RichText_ButtonURLPlaceholder,
                    clearButtonAccessibilityLabel: strings.WebSearch_RecentSectionClear,
                    hasClearButton: true,
                    autocapitalizationType: .none,
                    autocorrectionType: .no,
                    updated: { [weak self] text in
                        guard let self, let component = self.component else { return }
                        var updated = component.button
                        updated.action = .url(text)
                        component.update(updated)
                    },
                    tag: buttonURLInputTag
                ))))
            case let .copyText(text):
                fieldItems.append(AnyComponentWithIdentity(id: "copyText", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass, theme: theme,
                    initialText: text,
                    placeholder: strings.RichText_ButtonCopyTextPlaceholder,
                    hasClearButton: true,
                    updated: { [weak self] text in
                        guard let self, let component = self.component else { return }
                        var updated = component.button
                        updated.action = .copyText(text)
                        component.update(updated)
                    },
                    tag: buttonCopyTextInputTag
                ))))
            case .userProfile:
                fieldItems.append(AnyComponentWithIdentity(id: "userProfile", component: AnyComponent(
                    ButtonStyleRowComponent(
                        theme: theme,
                        title: component.profilePeer?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
                            ?? strings.RichText_ButtonChooseUser,
                        isSelected: false,
                        isAccent: component.profilePeer == nil,
                        action: { [weak self] in self?.component?.chooseUser() }
                    )
                )))
            case .disabled, .unsupported:
                break
            }
            // Read-only actions are explained in the section FOOTER rather than as a pseudo-item: the
            // action is not something the user can act on here, so it is guidance, not a row. The
            // opaque payload rides along untouched either way.
            let actionFooter = preservedActionDescription(component.button.action, strings)
            let fieldsSize = self.fieldsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass,
                    header: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(
                        string: strings.RichText_ButtonSectionContent, font: headerFont,
                        textColor: theme.list.freeTextColor
                    )), maximumNumberOfLines: 0)),
                    footer: actionFooter.flatMap { text in
                        AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(
                            string: text, font: headerFont, textColor: theme.list.freeTextColor
                        )), maximumNumberOfLines: 0))
                    },
                    items: fieldItems, displaySeparators: true
                )),
                environment: {}, containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let view = self.fieldsSection.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentSize.height), size: fieldsSize))
            }
            contentSize.height += fieldsSize.height + 24.0

            // Action type. Switching type starts the new payload empty; a profile is only set once a user
            // is picked, so choosing "User Profile" opens the picker and leaves the action alone until then.
            // Not offered for a preserved `.unsupported` action, which this sheet promises to keep verbatim.
            let currentAction = ButtonActionChoice.from(component.button.action)
            var isActionAuthorable = true
            if case .unsupported = component.button.action {
                isActionAuthorable = false
            }
            let actionItems = !isActionAuthorable ? [] : ButtonActionChoice.allCases.map { choice in
                AnyComponentWithIdentity(id: choice.title(strings), component: AnyComponent(
                    ButtonStyleRowComponent(
                        theme: theme,
                        title: choice.title(strings),
                        isSelected: choice == currentAction,
                        action: { [weak self] in
                            guard let self, let component = self.component, choice != currentAction else { return }
                            // End editing NOW, outside any update: the switch removes the payload field, and
                            // a field removed while focused resigns inside the update, whose end-editing
                            // callback re-enters it (a ComponentView assertion).
                            self.endEditing(true)
                            var updated = component.button
                            switch choice {
                            case .url:
                                updated.action = .url("")
                            case .copyText:
                                updated.action = .copyText("")
                            case .userProfile:
                                component.chooseUser()
                                return
                            }
                            component.update(updated)
                        }
                    )
                ))
            }
            let actionSize = self.actionSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass,
                    header: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(
                        string: strings.RichText_ButtonSectionAction, font: headerFont,
                        textColor: theme.list.freeTextColor
                    )), maximumNumberOfLines: 0)),
                    footer: nil, items: actionItems, displaySeparators: true
                )),
                environment: {}, containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let view = self.actionSection.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentSize.height), size: actionSize))
                view.isHidden = !isActionAuthorable
            }
            if isActionAuthorable {
                contentSize.height += actionSize.height + 24.0
            }

            // Style.
            let current = ButtonStyleChoice.from(component.button)
            let styleItems = ButtonStyleChoice.choices(isBlockPill: component.isBlockPill).map { choice in
                AnyComponentWithIdentity(id: choice.title(strings), component: AnyComponent(
                    ButtonStyleRowComponent(
                        theme: theme,
                        title: choice.title(strings),
                        isSelected: choice == current,
                        action: { [weak self] in
                            guard let self, let component = self.component else { return }
                            component.update(choice.apply(to: component.button))
                        }
                    )
                ))
            }
            let styleSize = self.styleSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass,
                    header: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(
                        string: strings.RichText_ButtonSectionStyle, font: headerFont,
                        textColor: theme.list.freeTextColor
                    )), maximumNumberOfLines: 0)),
                    footer: nil, items: styleItems, displaySeparators: true
                )),
                environment: {}, containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let view = self.styleSection.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentSize.height), size: styleSize))
            }
            contentSize.height += styleSize.height + 24.0

            // Delete.
            let deleteSize = self.deleteSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme, style: .glass, header: nil, footer: nil,
                    items: [AnyComponentWithIdentity(id: "delete", component: AnyComponent(
                        ButtonStyleRowComponent(
                            theme: theme,
                            title: strings.RichText_ButtonDelete,
                            isSelected: false,
                            isDestructive: true,
                            action: { [weak self] in self?.component?.complete(nil) }
                        )
                    ))],
                    displaySeparators: false
                )),
                environment: {}, containerSize: CGSize(width: sectionWidth, height: .greatestFiniteMagnitude)
            )
            if let view = self.deleteSection.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentSize.height), size: deleteSize))
            }
            contentSize.height += deleteSize.height

            // BOTTOM INSET: this sheet has no `bottomItem`, so the content only has to clear the home
            // indicator. (`TextProcessingScreen` reserves 106 because it hosts an action button there.)
            contentSize.height += 24.0 + environment.safeInsets.bottom

            return contentSize
        }
    }

    func makeView() -> View { View(frame: CGRect()) }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState,
                environment: Environment<ViewControllerComponentContainer.Environment>,
                transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state,
                    environment: environment, transition: transition)
    }
}

/// A tappable list row with an optional checkmark — the style and action pickers' item, reused for
/// Delete and for the profile button's user row (accent-coloured while it is a "Choose User" prompt).
private final class ButtonStyleRowComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let title: String
    let isSelected: Bool
    let isDestructive: Bool
    let isAccent: Bool
    let action: () -> Void

    init(theme: PresentationTheme, title: String, isSelected: Bool, isDestructive: Bool = false,
         isAccent: Bool = false, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.isAccent = isAccent
        self.action = action
    }

    static func ==(lhs: ButtonStyleRowComponent, rhs: ButtonStyleRowComponent) -> Bool {
        lhs.theme === rhs.theme && lhs.title == rhs.title
            && lhs.isSelected == rhs.isSelected && lhs.isDestructive == rhs.isDestructive
            && lhs.isAccent == rhs.isAccent
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private let titleLabel = UILabel()
        private let checkLabel = UILabel()
        private let button = UIButton(type: .custom)
        private var component: ButtonStyleRowComponent?

        var customUpdateIsHighlighted: ((Bool) -> Void)?
        var enumerateSiblings: (((UIView) -> Void) -> Void)?
        var separatorInset: CGFloat = 16.0

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.titleLabel)
            self.addSubview(self.checkLabel)
            self.addSubview(self.button)
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) { preconditionFailure() }

        @objc private func pressed() { self.component?.action() }

        func update(component: ButtonStyleRowComponent, availableSize: CGSize, state: EmptyComponentState,
                    environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.titleLabel.text = component.title
            self.titleLabel.font = Font.regular(17.0)
            if component.isDestructive {
                self.titleLabel.textColor = component.theme.list.itemDestructiveColor
            } else if component.isAccent {
                self.titleLabel.textColor = component.theme.list.itemAccentColor
            } else {
                self.titleLabel.textColor = component.theme.list.itemPrimaryTextColor
            }
            self.checkLabel.text = component.isSelected ? "✓" : ""
            self.checkLabel.font = Font.semibold(17.0)
            self.checkLabel.textColor = component.theme.list.itemAccentColor

            let height: CGFloat = 44.0
            let inset: CGFloat = 16.0
            self.titleLabel.frame = CGRect(x: inset, y: 0.0, width: availableSize.width - inset * 2.0 - 24.0, height: height)
            self.checkLabel.frame = CGRect(x: availableSize.width - inset - 24.0, y: 0.0, width: 24.0, height: height)
            self.button.frame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            return CGSize(width: availableSize.width, height: height)
        }
    }

    func makeView() -> View { View(frame: CGRect()) }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState,
                environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state,
                    environment: environment, transition: transition)
    }
}

// MARK: - Sheet wrapper + public screen

private final class ButtonEditorSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let initialButton: ButtonRef
    let isBlockPill: Bool
    let completion: (ButtonRef?) -> Void

    init(context: AccountContext, initialButton: ButtonRef, isBlockPill: Bool,
         completion: @escaping (ButtonRef?) -> Void) {
        self.context = context
        self.initialButton = initialButton
        self.isBlockPill = isBlockPill
        self.completion = completion
    }

    static func ==(lhs: ButtonEditorSheetComponent, rhs: ButtonEditorSheetComponent) -> Bool {
        lhs.context === rhs.context && lhs.initialButton == rhs.initialButton && lhs.isBlockPill == rhs.isBlockPill
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<()>>()
        private var component: ButtonEditorSheetComponent?
        private var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        /// The live edit. Seeded from the incoming button and mutated by the fields; committed on Done.
        private var button: ButtonRef?
        private var didComplete = false
        /// The user a `.userProfile` action names, for its row's title. Set by the picker, or resolved
        /// once from the local database for a button that already names one.
        private var profilePeer: EnginePeer?
        private var profilePeerDisposable: Disposable?

        override init(frame: CGRect) { super.init(frame: frame) }
        required init?(coder: NSCoder) { preconditionFailure() }

        deinit {
            self.profilePeerDisposable?.dispose()
        }

        private func chooseUser() {
            guard let component = self.component, let environment = self.environment else { return }
            // The pick replaces the payload field; it must not still be focused then (see the action rows).
            self.endEditing(true)
            let context = component.context
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
                context: context,
                // Saved Messages stays in: picking it links the author's own profile ("contact me").
                filter: [.onlyPrivateChats, .excludeSecretChats, .doNotSearchMessages],
                hasChatListSelector: false,
                title: environment.strings.RichText_ButtonChooseUser
            ))
            let host = UserPickerHostController(picker: controller, theme: environment.theme,
                                                cancelTitle: environment.strings.Common_Cancel)
            controller.peerSelected = { [weak self, weak host] peer, _ in
                host?.dismissAnimated()
                guard let self, let component = self.component, case .user = peer else { return }
                self.profilePeerDisposable?.dispose()
                self.profilePeerDisposable = nil
                self.profilePeer = peer
                var updated = self.button ?? component.initialButton
                updated.action = .userProfile(peerId: peer.id.toInt64())
                self.button = updated
                self.state?.updated(transition: .immediate)
            }
            environment.controller()?.present(host, in: .window(.root))
        }

        /// Resolves the name for a button that already names a user (an edited one, or one this sheet
        /// re-renders before the picker's peer is stored). Once per sheet: the picker sets the peer itself.
        private func resolveProfilePeerIfNeeded(context: AccountContext, action: ButtonAction) {
            guard case let .userProfile(rawPeerId) = action, self.profilePeer == nil,
                  self.profilePeerDisposable == nil else {
                return
            }
            self.profilePeerDisposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id(rawPeerId))
            ) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self, let peer, self.profilePeer == nil else { return }
                self.profilePeer = peer
                self.state?.updated(transition: .immediate)
            })
        }

        private func complete(_ result: ButtonRef?) {
            guard !self.didComplete, let component = self.component else { return }
            self.didComplete = true
            component.completion(result)
            self.dismiss(animated: true)
        }

        private func dismiss(animated: Bool) {
            guard let environment = self.environment else { return }
            if animated {
                self.animateOut.invoke(Action { _ in
                    environment.controller()?.dismiss(completion: nil)
                })
            } else {
                environment.controller()?.dismiss(completion: nil)
            }
        }

        func update(component: ButtonEditorSheetComponent, availableSize: CGSize, state: EmptyComponentState,
                    environment: Environment<ViewControllerComponentContainer.Environment>,
                    transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            let theme = environment.theme

            let button = self.button ?? component.initialButton
            self.resolveProfilePeerIfNeeded(context: component.context, action: button.action)
            // The row titles the user the action names; a peer left over from an earlier choice is not shown.
            var profilePeer: EnginePeer?
            if case let .userProfile(rawPeerId) = button.action, let peer = self.profilePeer,
               peer.id == EnginePeer.Id(rawPeerId) {
                profilePeer = peer
            }

            // The sheet owns the title and the two bar buttons; the content is just the sections.
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(ButtonEditorSheetContent(
                        context: component.context,
                        button: button,
                        isBlockPill: component.isBlockPill,
                        profilePeer: profilePeer,
                        update: { [weak self] updated in
                            guard let self else { return }
                            self.button = updated
                            Queue.mainQueue().justDispatch { [weak self] in
                                self?.state?.updated(transition: .immediate)
                            }
                        },
                        chooseUser: { [weak self] in self?.chooseUser() },
                        complete: { [weak self] result in self?.complete(result) }
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.RichText_ButtonEditorTitle,
                            font: Font.semibold(17.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                            BundleIconComponent(name: "Navigation/Close",
                                                tintColor: theme.chat.inputPanel.panelControlColor)
                        )),
                        action: { [weak self] _ in self?.dismiss(animated: true) }
                    )),
                    rightItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: theme.list.itemCheckColors.fillColor,
                        isDark: theme.overallDarkAppearance,
                        state: .tintedGlass,
                        component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                            BundleIconComponent(name: "Navigation/Done",
                                                tintColor: theme.list.itemCheckColors.foregroundColor)
                        )),
                        action: { [weak self] _ in
                            guard let self, let component = self.component else { return }
                            self.complete(self.button ?? component.initialButton)
                        }
                    )),
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { [weak self] animated in self?.dismiss(animated: animated) }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil { self.addSubview(sheetView) }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: sheetSize))
            }
            return availableSize
        }
    }

    func makeView() -> View { View(frame: CGRect()) }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState,
                environment: Environment<ViewControllerComponentContainer.Environment>,
                transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state,
                    environment: environment, transition: transition)
    }
}

/// Hosts the user picker at WINDOW level, above the sheet. The sheet is window-presented (so the editor
/// under it keeps the keyboard across it), which puts anything pushed onto the chat's navigation BELOW it;
/// and `PeerSelectionController` needs a navigation controller. So the picker gets a private one, as
/// `ShareScreenHostController` gives `ShareScreen`. The picker is that navigation's root, so it has no
/// modal close button or swipe-down: the host adds Cancel, and every exit goes through `dismissAnimated`
/// — an empty navigation left in the window would swallow the sheet's touches.
private final class UserPickerHostController: ViewController {
    private let navigation: NavigationController
    private var currentLayout: ContainerViewLayout?
    private var isAppearing = false
    private var isDismissing = false

    init(picker: PeerSelectionController, theme: PresentationTheme, cancelTitle: String) {
        self.navigation = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: theme))
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
        picker.navigationPresentation = .default
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(title: cancelTitle, style: .plain,
                                                                  target: self, action: #selector(self.cancelPressed))
        picker.customDismiss = { [weak self] in
            self?.dismissAnimated()
        }
        self.navigation.setViewControllers([picker], animated: false)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func cancelPressed() {
        self.dismissAnimated()
    }

    func dismissAnimated() {
        guard !self.isDismissing else { return }
        self.isDismissing = true
        self.view.endEditing(true)
        let height = self.currentLayout?.size.height ?? self.view.bounds.height
        self.displayNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: height), duration: 0.3,
                                               timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false,
                                               additive: true, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
        self.navigation.setIgnoreAppearanceMethodInvocations(true)
        self.displayNode.view.addSubview(self.navigation.view)
        self.navigation.setIgnoreAppearanceMethodInvocations(false)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.currentLayout = layout
        guard self.isAppearing else { return }
        transition.updateFrame(view: self.navigation.view, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.navigation.containerLayoutUpdated(layout, transition: transition)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !self.isAppearing {
            self.isAppearing = true
            if let layout = self.currentLayout {
                self.navigation.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                self.navigation.containerLayoutUpdated(layout, transition: .immediate)
                self.displayNode.layer.animatePosition(from: CGPoint(x: 0.0, y: layout.size.height), to: CGPoint(),
                                                       duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring,
                                                       additive: true)
            }
        }
        self.navigation.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigation.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigation.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigation.viewDidDisappear(animated)
    }
}

/// The pill property sheet. `completion` receives the edited button, or `nil` to delete it (which also
/// removes its row when it was the last pill). Dismissing without Done makes no change.
///
/// `isBlockPill` is the tapped pill's kind, as reported by `RichTextEditorView.onEditButtonRequested`.
/// It selects the authorable style set — a block-row pill is not offered the link style.
public final class ButtonEditorScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, button: ButtonRef, isBlockPill: Bool,
                completion: @escaping (ButtonRef?) -> Void) {
        super.init(
            context: context,
            component: ButtonEditorSheetComponent(context: context, initialButton: button,
                                                  isBlockPill: isBlockPill, completion: completion),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        self.navigationPresentation = .flatModal
    }

    required public init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let view = self.node.hostView.findTaggedView(tag: buttonLabelInputTag) as? ListTextFieldItemComponent.View {
            view.activateInput()
        }
    }
}
