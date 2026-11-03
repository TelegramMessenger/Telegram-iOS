import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import ChatTextInputPanelNode
import HarnessAppContext
import TextFormat
import ChatInputTextNode
import BrowserUI

/// Owns the real panel and everything it needs to be laid out.
///
/// **This is the design's weakest joint and it is marked as such.** In Telegram the panel is laid
/// out by `ChatControllerNode`, which has keyboard machinery this class does not reproduce.
/// Findings about HEIGHT or INSETS must be re-confirmed in the real app before being filed;
/// findings about the model, caret, formatting, paste or send run through code this class does not
/// touch. See the design doc §5.
public final class HarnessPanelHost {
    public let panel: ChatTextInputPanelNode
    public private(set) var interfaceState: ChatPresentationInterfaceState
    /// Called after the panel pushes a new input state up — every edit, caret move and formatting
    /// change, including the ones that neither change the height nor count as typing activity.
    public var inputStateDidChange: (() -> Void)?
    /// Asks the root for a URL (`current` pre-filled), answering nil for Cancel and "" for Remove.
    /// The chat presents `chatTextLinkEditController` here; the harness has no presentation stack
    /// for it, so the prompt is synthetic — what happens to the answer below is the chat's own code.
    public var promptForLink: ((_ selectedText: String, _ current: String?, _ completion: @escaping (String?) -> Void) -> Void)?

    private let context: HarnessAccountContext

    /// The other side of the chat. The composer's placeholder is chosen from the rendered peer
    /// (`ChatTextInputPanelNode.swift`, the `renderedPeer` switch), so with none it stays empty;
    /// and a chat with the account's own peer is Saved Messages, not an ordinary conversation.
    public static let chatPeer = TelegramUser(
        id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777001)),
        accessHash: nil, firstName: "Harness", lastName: "Chat", username: nil, phone: nil,
        photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
        storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
        profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)

    public init(
        context: HarnessAccountContext,
        settings: HarnessSettings,
        presentController: @escaping (ViewController) -> Void
    ) {
        self.context = context

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.interfaceState = ChatPresentationInterfaceState(
            chatWallpaper: .builtin(WallpaperSettings()),
            theme: presentationData.theme,
            preferredGlassType: .default,
            strings: presentationData.strings,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            limitsConfiguration: context.currentLimitsConfiguration.with { $0 },
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            accountPeerId: context.account.peerId,
            mode: .standard(.default),
            chatLocation: .peer(id: HarnessPanelHost.chatPeer.id),
            subject: nil,
            greetingData: nil,
            pendingUnpinnedAllMessages: false,
            activeGroupCallInfo: nil,
            hasActiveGroupCall: false,
            threadData: nil,
            isGeneralThreadClosed: nil,
            replyMessage: nil,
            accountPeerColor: nil,
            businessIntro: nil
        ).updatedPeer { _ in RenderedPeer(peer: HarnessPanelHost.chatPeer) }

        // `presentationContext: nil` is a real, used value — ChatInterfaceStateInputPanels.swift:484
        // constructs the panel exactly this way.
        self.panel = ChatTextInputPanelNode(
            context: context,
            presentationInterfaceState: self.interfaceState,
            presentationContext: nil,
            presentController: presentController
        )
        self.panel.context = context

        self.panel.interfaceInteraction = ChatPanelInterfaceInteraction(
            updateTextInputStateAndMode: { [weak self] f in
                guard let self else {
                    return
                }
                // As `ChatControllerLoadDisplayNode`'s closure does: every transform handed here is the
                // user's edit through the chat (autocomplete, the emoji keyboard, Translate…), so the
                // push it causes is applied as one undo step (`HarnessChatSideEditUndoTests`). External
                // sets reach the panel through `setInputContent` below instead and clear the stack.
                guard let node = self.panel.richTextInputNode else {
                    self.applyInputStateTransform(f)
                    return
                }
                node.performUndoableInputChange {
                    self.applyInputStateTransform(f)
                }
            },
            updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
                guard let self else {
                    return
                }
                let (updatedInputMode, _) = f(self.interfaceState)
                self.interfaceState = self.interfaceState.updatedInputMode { _ in updatedInputMode }
            },
            openLinkEditing: { [weak self] in
                self?.openLinkEditing()
            }
        )

        // The app's own wiring (`ChatInterfaceStateInputPanels.swift`, `pastedMarkdownParser`), whose
        // body is TelegramUI's `chatInputContentFromPastedMarkdown`: TelegramUI itself is not linkable
        // here, so its four lines are repeated over the same public parsers.
        self.panel.pastedMarkdownParser = { context, text in
            guard let attribute = inputRichTextAttributeFromText(context: context, text: text) else {
                return nil
            }
            let content = chatInputContentStrippingSelfReferentialLinks(chatInputContent(fromInstantPage: attribute.instantPage))
            return pastedMarkdownContentIsRicherThanPlain(content) ? content : nil
        }

        // The chat builds the input node lazily, on first use. The harness has no "first use" to
        // wait for, and a panel with no input node has no backend to report and nothing to type
        // into, so it is built here. This is the panel's own public entry point, not a shortcut
        // around it: it routes through `loadTextInputNode(useNative: self.alwaysUseNativeInput)`
        // and so makes the real backend decision from `:863-881`.
        self.panel.loadTextInputNodeIfNeeded()
    }

    /// The body of the chat's `updateTextInputStateAndMode` closure: the transform's state becomes the
    /// interface state and, having changed, is pushed back into the panel — what
    /// `ChatControllerNode.updateChatPresentationInterfaceState` does with a changed
    /// `effectiveInputState`. The legacy backend applies its Format-menu commands only this way (it
    /// computes the formatted state and hands it up), so without the push they did nothing; the
    /// engine's own edits come back as content-equal echoes, which is also what they meet in the app.
    private func applyInputStateTransform(_ f: (ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) {
        let previousState = self.interfaceState.interfaceState.effectiveInputState
        let (updatedState, updatedMode) = f(previousState, self.interfaceState.inputMode)
        self.interfaceState = self.interfaceState.updatedInterfaceState { interfaceState in
            return interfaceState.withUpdatedEffectiveInputState(updatedState)
        }.updatedInputMode { _ in updatedMode }
        if previousState != updatedState {
            self.panel.updateInputTextState(
                updatedState,
                keepSendButtonEnabled: false,
                extendedSearchLayout: false,
                accessoryItems: [],
                animated: false
            )
        }
        self.inputStateDidChange?()
    }

    /// Mirrors `openLinkEditing` in `ChatControllerLoadDisplayNode.swift`: the engine reads and
    /// applies the link through the node, legacy through the input state and the shared
    /// `chatTextInputAddLinkAttribute` / `chatTextInputRemoveLinkAttribute`.
    private func openLinkEditing() {
        guard let promptForLink = self.promptForLink else {
            return
        }
        if let node = self.panel.richTextInputNode, node.usesNativeRichTextEngine {
            promptForLink(node.selectedRichText(), node.currentRichTextLinkURL(), { [weak node] link in
                if let node, let link {
                    node.applyRichTextLink(link.isEmpty ? nil : link)
                }
            })
            return
        }
        let state = self.interfaceState.interfaceState.effectiveInputState
        let selectionRange = state.selectionRange
        let text = state.inputText.attributedSubstring(from: NSRange(location: selectionRange.lowerBound, length: selectionRange.count))
        var current: String?
        text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
            if let attribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                current = attribute.url
            }
        }
        promptForLink(text.string, current, { [weak self] link in
            guard let self, let link else {
                return
            }
            self.panel.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                if link.isEmpty {
                    return (chatTextInputRemoveLinkAttribute(current, selectionRange: selectionRange), inputMode)
                } else {
                    return (chatTextInputAddLinkAttribute(current, selectionRange: selectionRange, url: link), inputMode)
                }
            }
        })
    }

    /// Reads the backend the node ACTUALLY built, never the one the settings asked for. A harness
    /// that reported the requested arm would lie in exactly the direction this project keeps being
    /// burned by.
    ///
    /// **Optional, and that is the point.** `richTextInputNode` is nil until the panel builds it,
    /// and "no node yet" is not "legacy". The first version of this returned `.legacy` for nil and
    /// promptly produced a failing test that read as "the engine did not come up" when the truth
    /// was "nothing had been built yet" — the same plausible-constant trap the whole app-context
    /// design is written against. nil means nil.
    public var liveBackend: HarnessBackend? {
        guard let node = self.panel.richTextInputNode else {
            return nil
        }
        return node.usesNativeRichTextEngine ? .engine : .legacy
    }

    /// The height the last real layout pass produced. The readout reads THIS rather than
    /// re-measuring: a dump that laid the panel out would mutate the thing it is reporting on, and
    /// two consecutive reads could then disagree.
    public private(set) var lastMeasuredHeight: CGFloat = 0.0

    /// Sets the composer's content through the panel's OWN entry point.
    ///
    /// `ChatTextInputPanelNode` has no `setInputContent`; the chat controller calls
    /// `updateInputTextState(_:keepSendButtonEnabled:extendedSearchLayout:accessoryItems:animated:)`,
    /// which is what actually reaches `richTextInputNode.setInputContent`. Writing only the
    /// interface state is NOT enough and looks like it works: the panel's `inputTextState` getter
    /// (`:373`) reads back from the NODE, so the harness saw its own write disappear. Both halves
    /// are done here — the interface state so the next layout pass agrees, and the real call so
    /// the node actually receives the content.
    /// Replaces the presentation state the NEXT layout pass hands the panel — a theme change, as the
    /// chat delivers one (auto-night, Settings ▸ Appearance) while the composer has content. The panel
    /// reacts in `updateLayout`, so call `updateLayout` (or let the root's pass run) afterwards.
    public func updatePresentationInterfaceState(_ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) {
        self.interfaceState = f(self.interfaceState)
    }

    public func setInputContent(_ content: ChatInputContent) {
        // Caret at the end of the seeded content, where a user who had just typed it would be.
        // `plainText` is the flat axis the selection range indexes.
        let end = content.plainText.utf16.count
        self.setInputContent(content, selectionRange: end ..< end)
    }

    /// An EXTERNAL set with a selection — Send's clear, a draft synced from another device, a draft
    /// restored on open, an edit-message load. The chat makes those with
    /// `updateChatPresentationInterfaceState`, which reaches the panel through `ChatControllerNode`'s
    /// `updateInputTextState` and NOT through `interfaceInteraction.updateTextInputStateAndMode`: that
    /// closure is the user's edits' funnel (autocomplete, the emoji keyboard, Translate…) and applies
    /// them as undoable steps (`HarnessChatSideEditUndoTests`), where an external set empties the stack
    /// (`HarnessExternalSetUndoTests`).
    public func setInputContent(_ content: ChatInputContent, selectionRange: Range<Int>) {
        let state = ChatTextInputState(content: content, selectionRange: selectionRange)
        self.interfaceState = self.interfaceState.updatedInterfaceState { interfaceState in
            return interfaceState.withUpdatedEffectiveInputState(state)
        }
        self.panel.updateInputTextState(
            state,
            keepSendButtonEnabled: false,
            extendedSearchLayout: false,
            accessoryItems: [],
            animated: false
        )
    }

    /// The `maxHeight` the next layout pass hands the panel. The chat derives it from the space left
    /// above the keyboard, so lowering it is how a hosted test stands in for the keyboard coming up
    /// (p14, 2026-09-24). Findings that depend on it are HEIGHT findings and provisional.
    public var maxHeight: CGFloat = 400.0

    @discardableResult
    public func updateLayout(width: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let screenSize = UIScreen.main.bounds.size
        let height = self.panel.updateLayout(
            width: width,
            leftInset: 0.0,
            rightInset: 0.0,
            bottomInset: bottomInset,
            additionalSideInsets: UIEdgeInsets(),
            maxHeight: self.maxHeight,
            maxOverlayHeight: 0.0,
            isSecondary: false,
            transition: .immediate,
            interfaceState: self.interfaceState,
            metrics: LayoutMetrics(),
            deviceMetrics: DeviceMetrics(
                screenSize: screenSize,
                scale: UIScreen.main.scale,
                statusBarHeight: 54.0,
                onScreenNavigationHeight: 34.0
            ),
            isMediaInputExpanded: false
        )
        self.lastMeasuredHeight = height
        return height
    }
}
