import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatEntityKeyboardInputNode
import EntityKeyboard
import EmojiTextAttachmentView
import TextFormat
import SwiftSignalKit
import ViewControllerComponent
import RichTextEditorUIKit
import RichTextEngineEditor

/// Hosts the Telegram emoji keyboard (`ChatEntityKeyboardInputNode`, emoji-only) as a bottom panel for
/// a `RichTextEditorView`. Unicode emoji insert as text; custom emoji insert as inline custom-emoji
/// rendered live. The editor stays first responder with the system keyboard suppressed (caret visible).
@available(iOS 13.0, *)
final class RichTextEmojiKeyboardController {
    private let context: AccountContext
    private weak var editor: (any RichTextEditor)?
    private let requestLayout: () -> Void

    private let stateContext = ChatEntityKeyboardInputNode.StateContext()
    private var interaction: ChatEntityKeyboardInputNode.Interaction?
    private var inputNode: ChatEntityKeyboardInputNode?
    /// Whether the panel is currently slid into view (drives the slide-in/out animation).
    private var panelPresented = false
    private let dataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
    private var dataDisposable: Disposable?
    private var currentData: ChatEntityKeyboardInputNode.InputData?

    /// Files for custom emoji the user has inserted, keyed by fileId — the editor's emoji-view-provider
    /// resolves these to live `InlineStickerItemLayer` views. Seeded on open with the files of any emoji the
    /// initial document already references (`seedEmojiFiles`), so a custom emoji carried in from the chat
    /// composer renders without the user re-picking it, and its file survives back out (`currentEmojiFiles`).
    private var emojiFiles: [Int64: TelegramMediaFile] = [:]

    /// Seed the file store with custom-emoji files the initial document references (the editor `Document`
    /// itself carries only fileIds). Merge rather than replace, so a file the user later picks for the same
    /// fileId is not lost. Call before the editor's first layout, so the seeded emoji resolve on first render.
    func seedEmojiFiles(_ files: [Int64: TelegramMediaFile]) {
        for (fileId, file) in files {
            self.emojiFiles[fileId] = file
        }
    }

    /// The full file store (seeded + user-inserted), keyed by fileId — handed back so the caller can re-attach
    /// the `TelegramMediaFile` to each custom-emoji run when converting the editor's fileId-only `Document`
    /// back to the chat currency.
    var currentEmojiFiles: [Int64: TelegramMediaFile] {
        return self.emojiFiles
    }

    private(set) var isEmojiMode = false

    init(context: AccountContext, editor: any RichTextEditor, requestLayout: @escaping () -> Void) {
        self.context = context
        self.editor = editor
        self.requestLayout = requestLayout

        self.dataPromise.set(ChatEntityKeyboardInputNode.inputData(
            context: context,
            chatPeerId: nil,
            areCustomEmojiEnabled: true,
            hasTrending: false,
            hasSearch: true,
            hasStickers: false,
            hasGifs: false,
            hideBackground: false,
            maskEdge: .none,
            sendGif: nil
        ))
        self.dataDisposable = (self.dataPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            self.currentData = data
            if self.isEmojiMode {
                self.requestLayout()
            }
        })

        self.interaction = ChatEntityKeyboardInputNode.Interaction(
            sendSticker: { _, _, _, _, _, _, _, _, _ in return false },
            sendEmoji: { _, _, _ in },
            sendGif: { _, _, _, _, _ in return false },
            sendBotContextResultAsGif: { _, _, _, _, _, _ in return false },
            editGif: { _, _ in },
            updateChoosingSticker: { _ in },
            switchToTextInput: { [weak self] in self?.setEmojiMode(false) },
            dismissTextInput: { },
            insertText: { [weak self] attributedText in self?.handleInsert(attributedText) },
            backwardsDeleteText: { [weak self] in self?.editor?.deleteBackward() },
            openStickerEditor: { },
            presentController: { _, _ in },
            presentGlobalOverlayController: { _, _ in },
            getNavigationController: { return nil },
            requestLayout: { [weak self] _ in self?.requestLayout() }
        )
    }

    deinit {
        self.dataDisposable?.dispose()
    }

    func toggle() {
        self.setEmojiMode(!self.isEmojiMode)
    }

    func setEmojiMode(_ active: Bool) {
        guard active != self.isEmojiMode else { return }
        self.isEmojiMode = active
        if active {
            _ = self.editor?.becomeFirstResponder()
            // `EmptyInputView` (ChatEntityKeyboardInputNode) suppresses the system keyboard while the
            // canvas stays first responder, so the caret keeps rendering under the emoji panel.
            self.editor?.customInputView = EmptyInputView()
        } else {
            self.editor?.customInputView = nil
        }
        self.requestLayout()
    }

    private func handleInsert(_ attributedText: NSAttributedString) {
        guard attributedText.length > 0 else { return }
        if let emoji = attributedText.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) as? ChatTextInputTextCustomEmojiAttribute {
            if let file = emoji.file {
                self.emojiFiles[emoji.fileId] = file
            }
            let alt = attributedText.string
            self.editor?.insertEmoji(id: String(emoji.fileId), altText: alt.isEmpty ? nil : alt)
        } else {
            self.editor?.insertText(attributedText.string)
        }
    }

    /// Builds a fresh live custom-emoji view for the editor's emoji-view-provider. Returns nil for ids
    /// that are not recorded custom-emoji fileIds (the screen falls back to its demo glyphs).
    func customEmojiView(forId id: String, size: CGSize) -> (UIView & RichTextEmojiView)? {
        guard let fileId = Int64(id), let file = self.emojiFiles[fileId] else { return nil }
        let layer = InlineStickerItemLayer(
            context: self.context,
            userLocation: .other,
            attemptSynchronousLoad: true,
            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: file),
            file: file,
            cache: self.context.animationCache,
            renderer: self.context.animationRenderer,
            placeholderColor: UIColor(white: 0.5, alpha: 0.2),
            pointSize: size
        )
        layer.isVisibleForAnimations = true
        return RichTextInlineEmojiView(frame: CGRect(origin: .zero, size: size), contentLayer: layer)
    }

    /// Builds/positions the emoji panel inside `container`. Returns its height (0 when not in emoji mode).
    func updatePanel(container: UIView, availableSize: CGSize, environment: ViewControllerComponentContainer.Environment, transition: ComponentTransition) -> CGFloat {
        guard self.isEmojiMode, let currentData = self.currentData else {
            // Slide the panel down off-screen, then hide it (kept alive for reuse).
            if self.panelPresented, let node = self.inputNode {
                self.panelPresented = false
                let offscreenFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: CGSize(width: availableSize.width, height: node.view.frame.height))
                transition.setFrame(view: node.view, frame: offscreenFrame, completion: { [weak self, weak node] _ in
                    if self?.panelPresented == false {
                        node?.view.isHidden = true
                    }
                })
            }
            return 0.0
        }

        let node: ChatEntityKeyboardInputNode
        let animateIn: Bool
        if let existing = self.inputNode {
            node = existing
            animateIn = !self.panelPresented
        } else {
            node = ChatEntityKeyboardInputNode(
                context: self.context,
                currentInputData: currentData,
                updatedInputData: self.dataPromise.get(),
                defaultToEmojiTab: true,
                opaqueTopPanelBackground: false,
                useOpaqueTheme: false,
                interaction: self.interaction,
                chatPeerId: nil,
                stateContext: self.stateContext
            )
            node.clipsToBounds = true
            // Render the top panel (emoji-pack bar) INSIDE the node's bounds. Otherwise it defaults to an
            // external PagerExternalTopPanelContainer the host must place in its hierarchy — which we don't,
            // so the pack bar would be invisible (mirrors ComposePollScreen).
            node.externalTopPanelContainerImpl = nil
            self.inputNode = node
            container.addSubview(node.view)
            animateIn = true
        }
        node.view.isHidden = false
        self.panelPresented = true

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let presentationInterfaceState = ChatPresentationInterfaceState(
            chatWallpaper: .builtin(WallpaperSettings()),
            theme: presentationData.theme,
            preferredGlassType: .default,
            strings: presentationData.strings,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 },
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            accountPeerId: self.context.account.peerId,
            mode: .standard(.default),
            chatLocation: .peer(id: self.context.account.peerId),
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
        )

        let deviceMetrics = environment.deviceMetrics
        let standardInputHeight = deviceMetrics.standardInputHeight(inLandscape: false)
        let heightAndOverflow = node.updateLayout(
            width: availableSize.width,
            leftInset: environment.safeInsets.left,
            rightInset: environment.safeInsets.right,
            bottomInset: environment.safeInsets.bottom,
            standardInputHeight: standardInputHeight,
            inputHeight: standardInputHeight,
            maximumHeight: availableSize.height,
            inputPanelHeight: 0.0,
            transition: .immediate,
            interfaceState: presentationInterfaceState,
            layoutMetrics: environment.metrics,
            deviceMetrics: deviceMetrics,
            isVisible: true,
            isExpanded: false
        )
        let panelHeight = heightAndOverflow.0
        let shownFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - panelHeight), size: CGSize(width: availableSize.width, height: panelHeight))
        if animateIn {
            // Start off-screen at the bottom (non-animated) so the layout transition slides it up,
            // rather than animating from a fresh node's .zero frame (which looked like "from the top").
            let offscreenFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: shownFrame.size)
            ComponentTransition.immediate.setFrame(view: node.view, frame: offscreenFrame)
        }
        transition.setFrame(view: node.view, frame: shownFrame)
        return panelHeight
    }
}

/// A plain host view for one inline custom emoji, backed by an `InlineStickerItemLayer`. Conforms to the
/// editor's `RichTextEmojiView` so the editor can keep `dynamicColor` (the template-emoji tint) synced to
/// the current text color; the layer masks-and-tints itself for a custom template emoji.
private final class RichTextInlineEmojiView: UIView, RichTextEmojiView {
    private let contentLayer: InlineStickerItemLayer

    var dynamicColor: UIColor? {
        get { return self.contentLayer.dynamicColor }
        set { self.contentLayer.dynamicColor = newValue }
    }

    init(frame: CGRect, contentLayer: InlineStickerItemLayer) {
        self.contentLayer = contentLayer
        super.init(frame: frame)
        contentLayer.frame = self.bounds
        self.layer.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.contentLayer.frame = self.bounds
    }
}
