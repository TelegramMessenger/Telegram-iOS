import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import AttachmentUI
import ViewControllerComponent
import TelegramPresentationData
import PresentationDataUtils
import GlassBarButtonComponent
import GlassBackgroundComponent
import BundleIconComponent
import MultilineTextComponent
import EdgeEffect
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextButtonIcons
import RichTextEditorMediaView
import InstantPageUI
import ContextUI
import Postbox
import TelegramCore
import CheckNode
import GlassControls
import ChatRichTextEditorComposer
import ChatTextLinkEditUI
import TextFormat
import UndoUI
import SwiftSignalKit
import ChatSendMessageActionUI

/// `RichTextChecklistMarkerView` host wrapper backing a checklist item's checkbox with a `CheckNode`
/// (an `ASDisplayNode`, so we host its `.view` — this is a `UIView`, not a node). The editor frames this
/// view in the marker gutter and calls `setChecked(_:animated:)` when the item toggles. A private copy
/// lives in each editor host (cross-module; duplication is expected).
private final class HostChecklistCheckboxView: UIView, RichTextChecklistMarkerView {
    private let checkNode: CheckNode
    init(theme: CheckNodeTheme, checked: Bool) {
        self.checkNode = CheckNode(theme: theme, content: .check(isRectangle: true))
        super.init(frame: .zero)
        self.checkNode.isUserInteractionEnabled = false
        self.addSubview(self.checkNode.view)
        self.checkNode.setSelected(checked, animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.checkNode.frame = self.bounds
    }
    func setChecked(_ checked: Bool, animated: Bool) {
        self.checkNode.setSelected(checked, animated: animated)
    }
}

private final class RichTextSendButtonComponent: Component {
    let theme: PresentationTheme
    let isEnabled: Bool
    let isLocked: Bool
    let action: () -> Void
    let longPressAction: (() -> Void)?

    init(theme: PresentationTheme, isEnabled: Bool, isLocked: Bool, action: @escaping () -> Void, longPressAction: (() -> Void)?) {
        self.theme = theme
        self.isEnabled = isEnabled
        self.isLocked = isLocked
        self.action = action
        self.longPressAction = longPressAction
    }

    static func ==(lhs: RichTextSendButtonComponent, rhs: RichTextSendButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.isLocked != rhs.isLocked {
            return false
        }
        if (lhs.longPressAction == nil) != (rhs.longPressAction == nil) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let button = ComponentView<Empty>()
        private let buttonMaskView = UIView()
        private let buttonCutoutMaskView = UIImageView()
        private let lockBackgroundView = GlassBackgroundView()
        private let lockIconView = UIImageView()
        private var longPressGestureRecognizer: UILongPressGestureRecognizer?

        private var component: RichTextSendButtonComponent?

        override init(frame: CGRect) {
            self.buttonMaskView.backgroundColor = .white
            if let filter = CALayer.luminanceToAlpha() {
                self.buttonMaskView.layer.filters = [filter]
            }

            self.lockBackgroundView.isUserInteractionEnabled = false
            self.lockIconView.isUserInteractionEnabled = false

            super.init(frame: frame)

            self.clipsToBounds = false
            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            longPressGestureRecognizer.isEnabled = false
            self.longPressGestureRecognizer = longPressGestureRecognizer
            self.addGestureRecognizer(longPressGestureRecognizer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let component = self.component else {
                return
            }
            component.longPressAction?()
        }

        func update(component: RichTextSendButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.longPressGestureRecognizer?.isEnabled = component.longPressAction != nil

            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: component.theme,
                    preferClearGlass: false,
                    background: component.isEnabled ? .activeTint(inset: false) : .color(component.theme.chat.inputPanel.panelControlDisabledColor),
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Chat/Input/Text/SendIcon"), action: component.isEnabled ? component.action : nil)
                    ],
                    minWidth: 44.0
                )),
                environment: {},
                containerSize: availableSize
            )

            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(origin: .zero, size: buttonSize))

                if component.isLocked {
                    var animateIn = false
                    if buttonView.mask !== self.buttonMaskView {
                        buttonView.mask = self.buttonMaskView

                        if !transition.animation.isImmediate {
                            animateIn = true
                        }
                    }
                    let maskOverflow: CGFloat = 36.0
                    self.buttonMaskView.frame = CGRect(origin: CGPoint(x: -maskOverflow, y: -maskOverflow), size: CGSize(width: buttonSize.width + maskOverflow * 2.0, height: buttonSize.height + maskOverflow * 2.0))

                    let lockDiameter: CGFloat = 24.0
                    let lockOffset: CGFloat = -7.0
                    let cutoutInset: CGFloat = 2.0 - UIScreenPixel
                    let cutoutDiameter = lockDiameter + cutoutInset * 2.0
                    let lockFrame = CGRect(x: lockOffset, y: lockOffset, width: lockDiameter, height: lockDiameter)
                    let cutoutFrame = lockFrame.insetBy(dx: -cutoutInset, dy: -cutoutInset)

                    if self.buttonCutoutMaskView.image?.size.height != cutoutDiameter {
                        self.buttonCutoutMaskView.image = generateStretchableFilledCircleImage(diameter: cutoutDiameter, color: .black)
                    }
                    if self.buttonCutoutMaskView.superview == nil {
                        self.buttonMaskView.addSubview(self.buttonCutoutMaskView)
                    }
                    self.buttonCutoutMaskView.frame = cutoutFrame.offsetBy(dx: maskOverflow, dy: maskOverflow)

                    if self.lockBackgroundView.superview == nil {
                        self.addSubview(self.lockBackgroundView)
                    }
                    self.bringSubviewToFront(self.lockBackgroundView)
                    self.lockBackgroundView.update(size: lockFrame.size, cornerRadius: lockDiameter * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .custom(style: .default, color: component.theme.list.itemCheckColors.fillColor)), isInteractive: false, transition: transition)
                    transition.setFrame(view: self.lockBackgroundView, frame: lockFrame)
                    transition.setAlpha(view: self.lockBackgroundView, alpha: 1.0)

                    if self.lockIconView.image == nil {
                        self.lockIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/SmallLock"), color: .white)
                    }
                    if self.lockIconView.superview == nil {
                        self.lockBackgroundView.contentView.addSubview(self.lockIconView)
                    }
                    if let image = self.lockIconView.image {
                        let iconFrame = CGRect(
                            origin: CGPoint(
                                x: floorToScreenPixels((lockDiameter - image.size.width) * 0.5),
                                y: floorToScreenPixels((lockDiameter - image.size.height) * 0.5)
                            ),
                            size: image.size
                        )
                        transition.setFrame(view: self.lockIconView, frame: iconFrame)
                    }

                    if animateIn {
                        self.lockBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        self.lockBackgroundView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        self.buttonCutoutMaskView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    }
                } else {
                    if transition.animation.isImmediate {
                        if buttonView.mask === self.buttonMaskView {
                            buttonView.mask = nil
                        }
                        self.buttonCutoutMaskView.removeFromSuperview()
                        self.lockBackgroundView.removeFromSuperview()
                    } else {
                        self.lockBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        self.lockBackgroundView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            if buttonView.mask === self.buttonMaskView {
                                buttonView.mask = nil
                            }
                            self.buttonCutoutMaskView.removeFromSuperview()
                            self.lockBackgroundView.removeFromSuperview()
                            self.lockBackgroundView.layer.removeAllAnimations()
                            self.buttonCutoutMaskView.layer.removeAllAnimations()
                        })
                        self.buttonCutoutMaskView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    }
                }
            }

            return buttonSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class RichTextAttachmentScreenSendContextActions {
    public let peerId: EnginePeer.Id
    public let send: (RichTextAttachmentScreen.Document, [String: Media], [Int64: TelegramMediaFile], Bool, ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.SendParameters?) -> Void
    public let schedule: (RichTextAttachmentScreen.Document, [String: Media], [Int64: TelegramMediaFile], Bool, ChatSendMessageActionSheetController.SendParameters?) -> Void

    public init(
        peerId: EnginePeer.Id,
        send: @escaping (RichTextAttachmentScreen.Document, [String: Media], [Int64: TelegramMediaFile], Bool, ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.SendParameters?) -> Void,
        schedule: @escaping (RichTextAttachmentScreen.Document, [String: Media], [Int64: TelegramMediaFile], Bool, ChatSendMessageActionSheetController.SendParameters?) -> Void
    ) {
        self.peerId = peerId
        self.send = send
        self.schedule = schedule
    }
}

public class RichTextAttachmentScreen: ViewControllerComponentContainer, AttachmentContainable {
    public typealias Document = RichTextEditorCoreDocument
    
    public enum Mode {
        case standalone(savedDraft: Document?, media: [String: Media], emojiFiles: [Int64: TelegramMediaFile])
        case edit(initialDocument: Document?, media: [String: Media], emojiFiles: [Int64: TelegramMediaFile])
    }
    
    public enum RichTextAttachment {
        case image(ImageMediaReference)
        case file(FileMediaReference)
        case location(TelegramMediaMap)
    }
    
    public struct MediaRequest {
        public struct ImageOrVideo {
            public let limit: Int
            
            public init(limit: Int) {
                self.limit = limit
            }
        }
        
        public let imageOrVideo: ImageOrVideo?
        public let music: Bool
        public let file: Bool
        public let location: Bool
        
        public init(imageOrVideo: ImageOrVideo?, music: Bool, file: Bool, location: Bool) {
            self.imageOrVideo = imageOrVideo
            self.music = music
            self.file = file
            self.location = location
        }
    }
    
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = { return nil }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false

    public var mediaPickerContext: AttachmentMediaPickerContext?

    public var isPanGestureEnabled: (() -> Bool)? {
        return { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                return true
            }
            return componentView.isPanGestureEnabled()
        }
    }

    private let context: AccountContext
    private let sendMessage: (Document, [String: Media], [Int64: TelegramMediaFile], Bool) -> Void
    private let syncContent: ((Document, [String: Media], [Int64: TelegramMediaFile]) -> Void)?
    private let sendContextActions: RichTextAttachmentScreenSendContextActions?

    public convenience init(
        context: AccountContext,
        mode: Mode,
        sendMessage: @escaping (Document, [String: Media], [Int64: TelegramMediaFile]) -> Void,
        syncContent: ((Document, [String: Media], [Int64: TelegramMediaFile]) -> Void)? = nil,
        sendContextActions: RichTextAttachmentScreenSendContextActions? = nil,
        preuploadPeerId: EnginePeer.Id? = nil,
        presentAttachmentMenu: ((_ request: RichTextAttachmentScreen.MediaRequest, @escaping ([RichTextAttachmentScreen.RichTextAttachment]) -> Void) -> Void)?,
        presentFormulaEditor: ((_ initialValue: String?, _ completion: @escaping (String) -> Void) -> Void)?
    ) {
        self.init(
            context: context,
            mode: mode,
            sendMessage: { document, media, emojiFiles, _ in
                sendMessage(document, media, emojiFiles)
            },
            syncContent: syncContent,
            sendContextActions: sendContextActions,
            preuploadPeerId: preuploadPeerId,
            presentAttachmentMenu: presentAttachmentMenu,
            presentFormulaEditor: presentFormulaEditor
        )
    }

    public init(
        context: AccountContext,
        mode: Mode,
        sendMessage: @escaping (Document, [String: Media], [Int64: TelegramMediaFile], Bool) -> Void,
        syncContent: ((Document, [String: Media], [Int64: TelegramMediaFile]) -> Void)? = nil,
        sendContextActions: RichTextAttachmentScreenSendContextActions? = nil,
        /// Peer whose chat this content will be sent to. Media attached here pre-uploads against it;
        /// nil disables pre-upload (no peer to run `messages.uploadMedia` against).
        preuploadPeerId: EnginePeer.Id? = nil,
        presentAttachmentMenu: ((_ request: RichTextAttachmentScreen.MediaRequest, @escaping ([RichTextAttachmentScreen.RichTextAttachment]) -> Void) -> Void)?,
        presentFormulaEditor: ((_ initialValue: String?, _ completion: @escaping (String) -> Void) -> Void)?,
        pastedMarkdownParser: ((AccountContext, String) -> ChatInputContent?)? = nil
    ) {
        self.context = context
        self.sendMessage = sendMessage
        self.syncContent = syncContent
        self.sendContextActions = sendContextActions

        let overNavigationContainer = SparseContainerView()

        super.init(context: context, component: RichTextAttachmentScreenComponent(
            context: context,
            mode: mode,
            sendContextActions: sendContextActions,
            preuploadPeerId: preuploadPeerId,
            overNavigationContainer: overNavigationContainer,
            presentAttachmentMenu: presentAttachmentMenu,
            presentFormulaEditor: presentFormulaEditor,
            pastedMarkdownParser: pastedMarkdownParser
        ), navigationBarAppearance: .transparent, theme: .default)

        self._hasGlassStyle = true

        // Glass style: the Cancel/Done buttons are rendered by the View into
        // overNavigationContainer, so the nav item only needs an empty placeholder.
        self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: UIView()), animated: false)

        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(overNavigationContainer, at: 0)
        }
        
        self.attemptNavigation = { [weak self] _ in
            guard let self, let syncContent = self.syncContent, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                return true
            }
            syncContent(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
            return true
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func resetForReuse() {
        guard let syncContent = self.syncContent, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
            return
        }
        syncContent(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
    }
    
    fileprivate func donePressed() {
        guard let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
            return
        }
        if !componentView.isSendRichFormattingLocked {
            self.complete(withoutFormatting: false)
            return
        }

        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let controller = textAlertController(context: self.context, title: strings.RichText_RemoveFormattingTitle, text: strings.RichText_RemoveFormattingText, actions: [
            TextAlertAction(type: .defaultAction, title: strings.RichText_SubscribeToPremium, action: { [weak self] in
                guard let self else {
                    return
                }
                let premiumController = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .richText, forceDark: false, dismissed: nil)
                if let parentController = self.parentController() {
                    parentController.push(premiumController)
                } else {
                    self.push(premiumController)
                }
            }),
            TextAlertAction(type: .genericAction, title: strings.RichText_SendWithoutFormatting, action: { [weak self] in
                self?.complete(withoutFormatting: true)
            }),
            TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {
            })
        ], actionLayout: .vertical)
        self.present(controller, in: .window(.root))
    }

    fileprivate func complete(withoutFormatting: Bool) {
        guard let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
            self.dismiss()
            return
        }
        self.sendMessage(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles, withoutFormatting)
        self.dismiss()
    }

    fileprivate func close() {
        guard let syncContent = self.syncContent, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
            self.dismiss()
            return
        }
        syncContent(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
        self.dismiss()
    }

    fileprivate func displayLongPressSendMenu(sourceSendButton: UIView) {
        guard let sendContextActions = self.sendContextActions else {
            return
        }
        let context = self.context
        Task { @MainActor [weak self, weak sourceSendButton] in
            guard let self, let sourceSendButton else {
                return
            }
            let peerId = sendContextActions.peerId
            let previousSupportedOrientations = self.supportedOrientations

            let availableMessageEffects = await (context.availableMessageEffects |> take(1)).get()
            let hasPremium = await (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }).get()

            let peerStatus = await (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Presence(id: peerId)
            )).get()
            guard let peer = await (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )).get() else {
                return
            }

            let initialData = await ChatSendMessageContextScreen.initialData(context: context, currentMessageEffectId: nil).get()

            var sendWhenOnlineAvailable = false
            if let peerStatus, case let .present(until) = peerStatus.status {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                if currentTime > until {
                    sendWhenOnlineAvailable = true
                }
            }
            if peerId.namespace == Namespaces.Peer.CloudUser && peerId.id._internalGetInt64Value() == 777000 {
                sendWhenOnlineAvailable = false
            }

            let messageActionsController = makeChatSendMessageActionSheetController(
                initialData: initialData,
                context: context,
                updatedPresentationData: nil,
                peerId: peerId,
                params: .sendMessage(SendMessageActionSheetControllerParams.SendMessage(
                    isScheduledMessages: false,
                    mediaPreview: nil,
                    mediaCaptionIsAbove: nil,
                    messageEffect: (nil, { _ in }),
                    attachment: false,
                    canSendWhenOnline: sendWhenOnlineAvailable,
                    forwardMessageIds: [],
                    canMakePaidContent: false,
                    currentPrice: nil,
                    hasTimers: false,
                    sendPaidMessageStars: nil,
                    isMonoforum: peer.isMonoForum
                )),
                hasEntityKeyboard: false,
                gesture: nil,
                sourceSendButton: sourceSendButton,
                textInputSource: nil,
                emojiViewProvider: nil,
                completion: { [weak self] in
                    self?.supportedOrientations = previousSupportedOrientations
                },
                sendMessage: { [weak self] mode, parameters in
                    guard let self, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                        return
                    }
                    sendContextActions.send(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles, false, mode, parameters)
                    self.dismiss()
                },
                schedule: { [weak self] params in
                    guard let self, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                        return
                    }
                    sendContextActions.schedule(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles, false, params)
                    self.dismiss()
                },
                editPrice: { _ in
                },
                openPremiumPaywall: { [weak self] c in
                    guard let self else {
                        return
                    }
                    if let parentController = self.parentController() {
                        parentController.push(c)
                    } else {
                        self.push(c)
                    }
                },
                reactionItems: nil,
                availableMessageEffects: availableMessageEffects,
                isPremium: hasPremium
            )
            self.present(messageActionsController, in: .window(.root))
        }
    }
}

final class RichTextAttachmentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    // Held for the next step: the RichTextEditor demo will read context and add
    // its editor view into the View's content container.
    let context: AccountContext
    let mode: RichTextAttachmentScreen.Mode
    let sendContextActions: RichTextAttachmentScreenSendContextActions?
    let overNavigationContainer: UIView
    let preuploadPeerId: EnginePeer.Id?
    let presentAttachmentMenu: ((_ request: RichTextAttachmentScreen.MediaRequest, @escaping ([RichTextAttachmentScreen.RichTextAttachment]) -> Void) -> Void)?
    let presentFormulaEditor: ((_ initialValue: String?, _ completion: @escaping (String) -> Void) -> Void)?
    let pastedMarkdownParser: ((AccountContext, String) -> ChatInputContent?)?

    init(context: AccountContext, mode: RichTextAttachmentScreen.Mode, sendContextActions: RichTextAttachmentScreenSendContextActions?, preuploadPeerId: EnginePeer.Id?, overNavigationContainer: UIView, presentAttachmentMenu: ((_ request: RichTextAttachmentScreen.MediaRequest, @escaping ([RichTextAttachmentScreen.RichTextAttachment]) -> Void) -> Void)?, presentFormulaEditor: ((_ initialValue: String?, _ completion: @escaping (String) -> Void) -> Void)?, pastedMarkdownParser: ((AccountContext, String) -> ChatInputContent?)?) {
        self.context = context
        self.mode = mode
        self.sendContextActions = sendContextActions
        self.overNavigationContainer = overNavigationContainer
        self.preuploadPeerId = preuploadPeerId
        self.presentAttachmentMenu = presentAttachmentMenu
        self.presentFormulaEditor = presentFormulaEditor
        self.pastedMarkdownParser = pastedMarkdownParser
    }

    static func ==(lhs: RichTextAttachmentScreenComponent, rhs: RichTextAttachmentScreenComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let navigationTapView: UIView
        private let title = ComponentView<Empty>()
        private let leftNavActionsBar = ComponentView<Empty>()
        private let rightNavActionsBar = ComponentView<Empty>()
        
        private let editor = RichTextEditorView()
        // Frosted fade at the screen top (mirrors ComposePollScreen) — scrolling content dissolves into the
        // nav region. Overlaid above the editor; the nav buttons live in the separate over-nav container.
        private let topEdgeEffectView = EdgeEffectView()

        /// The current editor document, read by the controller's `donePressed`.
        var currentDocument: Document {
            return self.editor.document
        }

        /// Picked media keyed by the opaque `mediaID` handed to the editor. Read by `donePressed`.
        private var attachedMedia: [String: Media] = [:]

        /// Held for as long as this screen is open. Reconciled from the LIVE document, so removing a
        /// medium (or undoing its insertion) releases its need and the upload is grace-cancelled.
        private var preuploadNeeds: MediaPreuploadNeeds?
        /// One progress subscription per medium currently in the document.
        private var preuploadObservers: [EngineMedia.Id: Disposable] = [:]

        deinit {
            for (_, disposable) in self.preuploadObservers {
                disposable.dispose()
            }
        }

        /// Every `mediaID` the document references, including inside tables, quotes and details.
        private static func mediaIDs(in blocks: [Block], into result: inout [String]) {
            for block in blocks {
                switch block {
                case let .media(mediaBlock):
                    for item in mediaBlock.items {
                        result.append(item.mediaID)
                    }
                case let .blockQuote(quote):
                    mediaIDs(in: quote.children, into: &result)
                case let .details(details):
                    mediaIDs(in: details.children, into: &result)
                case let .table(table):
                    for row in table.rows {
                        for cell in row.cells {
                            mediaIDs(in: cell.blocks, into: &result)
                        }
                    }
                case .paragraph, .code, .pullQuote, .buttonRow:
                    break
                }
            }
        }

        /// Bring the set of uploading media in line with what the document currently references,
        /// and (re)bind a progress subscription for each. Cheap enough to run on every edit: it is a
        /// walk of the block tree plus dictionary work, no conversion.
        private func reconcilePreupload() {
            guard let component = self.component, let peerId = component.preuploadPeerId else {
                return
            }

            var ids: [String] = []
            Self.mediaIDs(in: self.editor.document.blocks, into: &ids)

            var media: [EngineMedia] = []
            var live = Set<EngineMedia.Id>()
            for mediaID in ids {
                guard let value = self.attachedMedia[mediaID], let id = value.id, !live.contains(id) else {
                    continue
                }
                live.insert(id)
                media.append(EngineMedia(value))
            }

            let needs: MediaPreuploadNeeds
            if let existing = self.preuploadNeeds {
                needs = existing
            } else {
                needs = component.context.engine.messages.makeMediaPreuploadNeeds()
                self.preuploadNeeds = needs
            }
            needs.update(peerId: peerId, media: media)

            for (id, disposable) in self.preuploadObservers where !live.contains(id) {
                disposable.dispose()
                self.preuploadObservers.removeValue(forKey: id)
            }
            for id in live where self.preuploadObservers[id] == nil {
                self.preuploadObservers[id] = (component.context.engine.messages.mediaPreuploadState(id: id)
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    self?.applyPreuploadState(state, for: id)
                })
            }
        }

        /// Apply one medium's pre-upload state.
        ///
        /// On `.done` the local `Media` is REPLACED BY the cloud one **at the key the document
        /// already references** — the editor addresses media by an opaque `mediaID` string, so the
        /// value swap promotes the medium everywhere downstream with no document mutation, no undo
        /// entry and no relayout. Re-deriving the key from the cloud media would be a bug: promotion
        /// changes the `MediaId`, so the new key is one the document does not reference and the
        /// medium would silently vanish on read-back.
        private func applyPreuploadState(_ state: EngineMediaPreuploadState?, for id: EngineMedia.Id) {
            guard let component = self.component else {
                return
            }
            switch state {
            case .progress:
                // Progress display is owned by RichTextMediaContentComponent, which subscribes to the
                // same state itself. This observer exists ONLY for the promotion write-back below.
                return
            case let .done(cloudMedia):
                let raw = cloudMedia._asMedia()
                guard let key = self.attachedMedia.first(where: { $0.value.id == id })?.key,
                      let localMedia = self.attachedMedia[key] else {
                    return
                }
                // Let the already-downloaded local bytes serve the cloud resource, so the promoted
                // medium does not flash a placeholder.
                if let localResource = preuploadPrimaryResource(localMedia), let cloudResource = preuploadPrimaryResource(raw) {
                    component.context.engine.resources.moveResourceData(
                        from: EngineMediaResource.Id(localResource.id),
                        to: EngineMediaResource.Id(cloudResource.id),
                        synchronous: true
                    )
                }
                self.attachedMedia[key] = raw
            case .failed, .none:
                return
            }
            // Guarded like `editor.onChange`: this can land during a layout pass (the first progress
            // value often arrives synchronously on subscribe), and re-entering `update` from inside
            // it is what the composer's requestLayout re-entry guard exists to prevent.
            guard !self.isUpdating else {
                return
            }
            self.componentState?.updated(transition: .immediate)
        }

        /// The picked media map, keyed by the editor's `mediaID`. Read by the controller's `donePressed`.
        var currentMedia: [String: Media] {
            return self.attachedMedia
        }

        /// The custom-emoji file store (seeded + user-inserted), keyed by fileId. Read by the controller's
        /// `donePressed` so each emoji run's `TelegramMediaFile` is re-attached when converting back.
        var currentEmojiFiles: [Int64: TelegramMediaFile] {
            return self.emojiKeyboard?.currentEmojiFiles ?? [:]
        }

        var isSendRichFormattingLocked: Bool {
            guard let component = self.component, !component.context.isPremium else {
                return false
            }
            let content = chatInputContent(fromDocument: self.currentDocument, media: self.currentMedia, emojiFiles: self.currentEmojiFiles)
            return !content.isEmpty && !content.isEntityExpressible(options: [.quotesRequireRichContent])
        }

        private var component: RichTextAttachmentScreenComponent?
        private var environment: EnvironmentType?
        
        private let actionBar = ComponentView<Empty>()
        private let aiButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let sendButtonExtractedContainer = ContextExtractedContentContainingView()

        private var emojiKeyboard: RichTextEmojiKeyboardController?
        private var componentState: EmptyComponentState?
        private var isUpdating = false
        private var lastTabBarVisible: Bool?
        private var didShowPremiumToast = false
        /// The `PresentationTheme` last mapped into the editor. `PresentationTheme` is a shared `final
        /// class`, so reference inequality is the cheap change-signal — guarding the editor `theme` setter
        /// (which does an unconditional reload+redraw) against firing on every keystroke (`onChange` →
        /// `componentState.updated` → `update`).
        private var appliedTheme: PresentationTheme?

        override init(frame: CGRect) {
            self.navigationTapView = UIView()
            
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func isPanGestureEnabled() -> Bool {
            return !viewTreeContainsFirstResponder(view: self.editor)
        }
        
        private func textCell(_ id: String, _ lines: [String]) -> Cell {
            Cell(id: BlockID(id), blocks: lines.enumerated().map { i, t in
                .paragraph(ParagraphBlock(id: BlockID("\(id)p\(i)"), runs: [TextRun(text: t)]))
            })
        }

        // MARK: Phase 5b — image picker + link prompt

        /// Picks one medium via the host attachment menu, registers its raw `Media` in `attachedMedia` (so the
        /// media-view provider can resolve it), and hands back the editor-facing `(mediaID, naturalSize, kind,
        /// caption)`. Callers decide what to do with it (insert a new block, or append to an existing one).
        private func pickMedia(request: RichTextAttachmentScreen.MediaRequest, completion: @escaping (_ items: [(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun])]) -> Void) {
            guard let component = self.component else {
                return
            }
            component.presentAttachmentMenu?(request, { [weak self] attachments in
                guard let self else {
                    return
                }
                var results: [(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun])] = []
                for attachment in attachments {
                    let media: Media
                    let kind: MediaKind
                    let naturalSize: CGSize
                    switch attachment {
                    case let .image(imageReference):
                        let image = imageReference.media
                        media = image
                        kind = .image
                        naturalSize = image.representations.last?.dimensions.cgSize ?? CGSize(width: 1, height: 1)
                    case let .file(fileReference):
                        let file = fileReference.media
                        if file.isVideo {
                            media = file
                            kind = .video
                            naturalSize = file.dimensions?.cgSize ?? CGSize(width: 1, height: 1)
                        } else if file.isMusic || file.isVoice {
                            // Audio (music from the Audio picker; voice only via edit round-trips). The block is a
                            // fixed-height row, so naturalSize is ignored by MediaBlockBox — pass a 1x1 placeholder.
                            media = file
                            kind = .audio
                            naturalSize = CGSize(width: 1.0, height: 1.0)
                        } else {
                            // Everything else from the Files tab is a document row — including an image-mime
                            // file, matching that tab's "send as file" meaning. Also a fixed-height row, so
                            // naturalSize is ignored by MediaBlockBox; pass the same 1x1 placeholder as audio.
                            media = file
                            kind = .document
                            naturalSize = CGSize(width: 1.0, height: 1.0)
                        }
                    case let .location(map):
                        // A map is id-less, so mint a deterministic key from its coordinates; the venue title (if any)
                        // seeds the caption (a raw dropped pin has no venue -> empty caption). Self-contained, since
                        // the shared `media.id` path below can't key an id-less medium.
                        let mediaID = "map:\(map.latitude):\(map.longitude)"
                        self.attachedMedia[mediaID] = map
                        let caption: [TextRun] = map.venue?.title.isEmpty == false ? [TextRun(text: map.venue!.title)] : []
                        results.append((mediaID, CGSize(width: 600.0, height: 300.0), .location, caption))
                        continue
                    }
                    guard let mediaId = media.id else { continue }
                    let mediaID = "\(mediaId.namespace):\(mediaId.id)"
                    self.attachedMedia[mediaID] = media
                    results.append((mediaID, naturalSize, kind, []))
                }
                // Called here as well as from onChange: attachedMedia is populated in this closure,
                // so the need is held from the earliest possible moment. The onChange reconcile that
                // follows the insert is then a no-op for these ids.
                self.reconcilePreupload()
                completion(results)
            })
        }

        private func presentImagePicker() {
            self.pickMedia(request: RichTextAttachmentScreen.MediaRequest(
                imageOrVideo: RichTextAttachmentScreen.MediaRequest.ImageOrVideo(limit: 10),
                music: true,
                file: true,
                location: true
            )) { [weak self] items in
                guard let self else { return }
                if items.count == 1 {
                    let item = items[0]
                    self.editor.insertMedia(mediaID: item.mediaID, naturalSize: item.naturalSize, kind: item.kind, caption: item.caption)
                } else if items.count >= 2 {
                    // Multi-select only ever surfaces photos/videos (the gallery tab is the only
                    // multiselect-enabled source; music/location are single). So a >=2 batch is always a
                    // valid photo/video album -> one mosaic MediaBlock, inserted as one undo step.
                    let mediaItems = items.map { item in
                        MediaItem(
                            mediaID: item.mediaID,
                            kind: item.kind,
                            naturalSize: Size2D(width: Double(item.naturalSize.width), height: Double(item.naturalSize.height))
                        )
                    }
                    let block = MediaBlock(id: BlockID.generate(), items: mediaItems)
                    self.editor.insertDocument(Document(blocks: [.media(block)]))
                }
            }
        }

        private func presentLinkPrompt() {
            guard let component = self.component, let environment = self.environment,
                  let controller = environment.controller() as? RichTextAttachmentScreen else {
                return
            }

            // Reuse the shared chat link-editing UI (title/selected-text label/URL field + webpage preview),
            // reading the current selection + existing link from the editor's native API and applying the
            // result back through it — mirrors the chat composer's `openLinkEditing` rich-text branch.
            let selectedText = self.editor.selectedText()
            let existingLink = self.editor.currentLink()

            let linkController = chatTextLinkEditController(
                context: component.context,
                text: environment.strings.TextFormat_AddLinkText(selectedText).string,
                link: existingLink,
                apply: { [weak self] link, _ in
                    guard let self, let link else { return }
                    self.editor.becomeFirstResponder()
                    if link.isEmpty {
                        self.editor.removeLink()
                    } else {
                        self.editor.setLink(link)
                    }
                }
            )
            controller.present(linkController, in: .window(.root))
        }

        /// Presents the list-marker picker (None / Bullet / Numbered / Checklist), applying the choice to
        /// the paragraphs the current caret or selection touches. Shared by the caret-case "add block"
        /// bar and the text-only selection bar.
        private func presentListMenu(from sourceView: UIView) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            guard let controller = environment.controller() as? RichTextAttachmentScreen else {
                return
            }

            let current = self.editor.currentState().listMarker

            var items: [ContextMenuItem] = []

            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_List_None, icon: { theme in
                UIImage()
            }, additionalLeftIcon: { theme in
                return current == nil ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.editor.setList(nil)
            })))

            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_List_Bullet, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatBulletList"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: { theme in
                return current == .bullet ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, iconPosition: .left, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.editor.setList(.bullet)
            })))

            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_List_Numbered, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatNumberList"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: { theme in
                return current == .ordered ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, iconPosition: .left, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.editor.setList(.ordered)
            })))

            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_List_Checklist, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatChecklist"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: { theme in
                return current == .checklist ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, iconPosition: .left, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.editor.setList(.checklist)
            })))

            // "Detail Block" — an INSERT action (no checkmark, unlike the marker toggles above): inserts a
            // fresh, expanded folding block at the caret. Not premium-gated (matches its list-menu siblings).
            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_List_Detail, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Expand"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.editor.insertDetailsBlock()
            })))

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let contextController = makeContextController(
                presentationData: presentationData,
                source: .reference(RichTextActionContextReferenceSource(sourceView: sourceView, containerView: controller.view)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            (controller.parentController() ?? controller).presentInGlobalOverlay(contextController)
        }
        
        /// Normalizes the caret's / selection's paragraph(s) to plain body text, stripping any block
        /// container they sit in: a code block or pull quote is toggled back to body paragraphs; a list
        /// marker and every enclosing block-quote level are removed; a heading (or any other non-body
        /// style) is down-converted. Backs the "Text" item in `presentAddMenu`.
        private func convertToBodyText() {
            let live = self.editor.currentState()
            // Code blocks and pull quotes are standalone box types, each with its own toggle-off that
            // splits back into body paragraphs — so they replace, rather than compose with, the steps below.
            if live.isCodeBlock {
                self.editor.makeCodeBlock()
                return
            }
            if live.isPullQuote {
                self.editor.makePullQuote()
                return
            }
            // Unwrap every enclosing block-quote level FIRST: `setList` only mutates top-level boxes, so a
            // quoted list item must be promoted to a top-level paragraph before its list marker can be cleared.
            var guardCount = 0
            while self.editor.currentState().blockQuoteDepth > 0 && guardCount < 32 {
                self.editor.unwrapBlockQuoteLevel()
                guardCount += 1
            }
            if self.editor.currentState().listMarker != nil {
                self.editor.setList(nil)
            }
            self.editor.setParagraphStyle(.body)
        }

        /// When the editor is unfocused (no caret), an Add-menu format/insert action should target the END of
        /// the document, not the default offset-0 start (which touches no paragraph, so the command no-ops).
        /// Focuses the editor and drops the caret at the end so the following command applies there. No-op when
        /// a caret already exists — the user's position is preserved.
        private func focusEditorAtDocumentEndIfNeeded(hasCursor: Bool) {
            guard !hasCursor else { return }
            self.editor.becomeFirstResponder()
            self.editor.moveCaretToDocumentEnd()
        }

        private func presentAddMenu(from sourceView: UIView) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() as? RichTextAttachmentScreen else {
                return
            }

            let editorState = self.editor.currentState()
            // Captured at menu-open time (before presenting can change first-responder state): whether the user
            // has a live caret. When false, the Add-menu actions target the document end instead of offset 0.
            let hasCursor = viewTreeContainsFirstResponder(view: self.editor)

            var items: [ContextMenuItem] = []
            
            if !editorState.hasSelection {
                items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuHeading, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatHeading"), color: theme.contextMenu.primaryColor)
                }, additionalLeftIcon: component.context.isPremium ? nil : { _ in
                    return UIImage(bundleImageName: "Premium/ContextStar")
                }, action: { [weak self] c, _ in
                    guard let self, let environment = self.environment else {
                        c?.dismiss(completion: nil)
                        return
                    }
                    
                    let live = self.editor.currentState()
                    
                    var subItems: [ContextMenuItem] = []
                    subItems.append(.action(ContextMenuActionItem(text: environment.strings.ChatList_Context_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { c, _ in
                        c?.popItems()
                    })))
                    subItems.append(.separator)
                    for level in 0 ..< 6 {
                        let fontSize: CGFloat
                        switch level {
                        case 0:
                            fontSize = 24
                        case 1:
                            fontSize = 21
                        case 2:
                            fontSize = 19
                        case 3:
                            fontSize = 18
                        case 4:
                            fontSize = 17
                        case 5:
                            fontSize = 16
                        default:
                            fontSize = 24
                        }
                        
                        let mappedStyle: ParagraphStyleName
                        switch level {
                        case 0:
                            mappedStyle = .heading1
                        case 1:
                            mappedStyle = .heading2
                        case 2:
                            mappedStyle = .heading3
                        case 3:
                            mappedStyle = .heading4
                        case 4:
                            mappedStyle = .heading5
                        case 5:
                            mappedStyle = .heading6
                        default:
                            mappedStyle = .heading1
                        }
                        
                        subItems.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuHeadingItem("\(level + 1)").string, textFont: .custom(font: Font.with(size: fontSize, design: .serif, weight: .semibold), height: nil, verticalOffset: nil), icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatHeading\(level + 1)"), color: theme.contextMenu.primaryColor)
                        }, additionalLeftIcon: { theme in
                            return live.paragraphStyle == mappedStyle ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
                        }, iconPosition: .left, action: { [weak self] _, f in
                            guard let self else {
                                f(.default)
                                return
                            }

                            if hasCursor {
                                self.editor.setParagraphStyle(mappedStyle)
                            } else {
                                // No caret: append a NEW empty paragraph with this heading style at the end and
                                // focus it, rather than converting an existing paragraph (a no-op at offset 0).
                                self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                                self.editor.insertDocument(Document(blocks: [.paragraph(ParagraphBlock(id: BlockID.generate(), style: mappedStyle))]))
                            }

                            f(.default)
                        })))
                    }
                    c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                })))
            }
            
            // "Text" normalizes to a plain body paragraph. Offer it whenever there is no selection (so the
            // caret's paragraph can always be reset — e.g. a heading down-converted), or when the selection
            // is not already plain body text: it sits in a block container (quote / code / list / pull quote)
            // or carries a non-body paragraph style (a heading). Tapping it strips that container/style.
            let isPlainBody = !editorState.isCodeBlock
                && !editorState.isPullQuote
                && editorState.listMarker == nil
                && editorState.blockQuoteDepth == 0
                && (editorState.paragraphStyle == nil || editorState.paragraphStyle == .body)
            if !editorState.hasSelection || !isPlainBody {
                items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuText, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatText"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    guard let self else {
                        c?.dismiss(completion: nil)
                        return
                    }

                    self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                    self.convertToBodyText()
                    c?.dismiss(completion: nil)
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuQuote, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatQuote"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }

                self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                let live = self.editor.currentState()
                if live.blockQuoteDepth > 0 {
                    self.editor.unwrapBlockQuoteLevel()
                } else {
                    self.editor.wrapInBlockQuote()
                }
                c?.dismiss(completion: nil)
            })))
            
            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuPullquote, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatPullquote"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: component.context.isPremium ? nil : { _ in
                return UIImage(bundleImageName: "Premium/ContextStar")
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }
                
                self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                let live = self.editor.currentState()
                if live.blockQuoteDepth > 0 {
                    self.editor.unwrapBlockQuoteLevel()
                }
                if live.isPullQuote {
                } else {
                    self.editor.makePullQuote()
                }
                c?.dismiss(completion: nil)
            })))
            
            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuCode, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatCode"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: component.context.isPremium ? nil : { _ in
                return UIImage(bundleImageName: "Premium/ContextStar")
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }
                
                self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                let live = self.editor.currentState()
                if live.blockQuoteDepth > 0 {
                    self.editor.unwrapBlockQuoteLevel()
                }
                if live.isCodeBlock {
                } else {
                    self.editor.makeCodeBlock()
                }
                c?.dismiss(completion: nil)
            })))
            
            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuFormula, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FormatFormula"), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: component.context.isPremium ? nil : { _ in
                return UIImage(bundleImageName: "Premium/ContextStar")
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }

                self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                self.component?.presentFormulaEditor?(nil, { [weak self] latex in
                    guard let self else {
                        return
                    }
                    self.editor.insertFormula(latex: latex)
                    DispatchQueue.main.async { [weak self] in
                        self?.editor.becomeFirstResponder()
                    }
                })
                
                c?.dismiss(completion: nil)
            })))
            
            // Buttons. With a SELECTION the item converts it into one inline pill (the Link flow's
            // analogue); with no selection it drops a block row, whose sheet the user opens by tapping
            // the pill.
            if editorState.hasSelection {
                items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuInlineButton, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    self?.editor.makeSelectionInlineButton()
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_MenuButtonRow, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    guard let self else {
                        return
                    }
                    // No caret: drop the row at the document end, not at offset 0 — same rule as insertTable.
                    self.focusEditorAtDocumentEndIfNeeded(hasCursor: hasCursor)
                    self.editor.insertButtonRow()
                })))
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let contextController = makeContextController(
                presentationData: presentationData,
                source: .reference(RichTextActionContextReferenceSource(sourceView: sourceView, containerView: controller.view)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            (controller.parentController() ?? controller).presentInGlobalOverlay(contextController)
        }

        private func presentActionMenu(from sourceView: UIView, items: [ContextMenuItem], actionsPosition: ContextControllerReferenceViewInfo.ActionsPosition = .top) {
            guard let component = self.component else { return }
            guard let selfController = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let controller = makeContextController(
                presentationData: presentationData,
                source: .reference(RichTextActionContextReferenceSource(sourceView: sourceView, containerView: selfController.view, actionsPosition: actionsPosition)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            selfController.presentInGlobalOverlay(controller)
        }

        /// Maps the app theme to the editor's render colors. Every value is `PresentationTheme`-derived —
        /// no OS-semantic `UIColor` survives on this path. accent/table derivations mirror the chat
        /// composer (`ChatTextInputPanelNode.makeRichTextThemeColors`); text uses `list.item*` because the
        /// screen's surface is `list.plainBackgroundColor`.
        private static func mapEditorTheme(_ theme: PresentationTheme) -> RichTextEditorTheme {
            let codeFill = theme.list.itemAccentColor.withMultipliedAlpha(0.1)
            // A code BLOCK's band takes the highlighted-table-cell fill, not an accent tint — one
            // local so the two cannot drift (the renderer binds them the same way, via
            // `tableHeaderColor`). Inline code keeps `codeFill`: a run-level pill inside body text
            // is a different surface from a full-width block band.
            let tableHighlightFill = theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05)
            
            let shadowCursorColor: UIColor
            if theme.overallDarkAppearance {
                shadowCursorColor = UIColor(white: 1.0, alpha: 0.4)
            } else {
                shadowCursorColor = UIColor(white: 0.0, alpha: 0.3)
            }
            
            return RichTextEditorTheme(
                primaryText: theme.list.itemPrimaryTextColor,
                secondaryText: theme.list.itemSecondaryTextColor,
                placeholder: theme.list.itemPlaceholderTextColor,
                accent: theme.list.itemAccentColor,
                tableBorder: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                tableHeaderBackground: tableHighlightFill,
                codeBackground: tableHighlightFill,
                listMarker: theme.list.itemPrimaryTextColor,
                inlineCodeBackground: codeFill,
                markedTextUnderline: theme.list.itemPrimaryTextColor,
                spoilerDust: theme.list.itemSecondaryTextColor,
                containerPlaceholder: theme.list.itemPlaceholderTextColor.mixedWith(theme.list.itemAccentColor, alpha: 0.15).withMultipliedBrightnessBy(theme.overallDarkAppearance ? 1.1 : 0.9),
                shadowCursor: shadowCursorColor,
                quoteAuthorText: theme.list.itemAccentColor,
                quoteAuthorPlaceholder: theme.list.itemPlaceholderTextColor.mixedWith(theme.list.itemAccentColor, alpha: 0.15).withMultipliedBrightnessBy(theme.overallDarkAppearance ? 1.1 : 0.9),
                // Pill colours, mirroring `instantPageButtonColors`: the neutral pill takes the panel
                // fill + accent label, and danger/success carry the LABEL colour (the editor derives
                // their 15% fills itself, as the renderer does).
                buttonNeutralFill: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.08),
                buttonNeutralLabel: theme.list.itemAccentColor,
                buttonDanger: theme.list.itemDestructiveColor,
                buttonSuccess: theme.list.itemDisclosureActions.constructive.fillColor
            )
        }

        func presentPremiumToast() {
            guard let component = self.component, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            let overlayController = UndoOverlayController(
                presentationData: presentationData,
                content: .premiumPaywall(title: nil, text: presentationData.strings.RichText_PremiumToastText, customUndoText: nil, timeout: nil, linkAction: nil),
                elevatedLayout: true,
                action: { action in
                    if case .info = action {

                    }
                    return true
                }
            )
            (controller.parentController() ?? controller).presentInGlobalOverlay(overlayController)
        }

        func update(component: RichTextAttachmentScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.componentState = state
            self.environment = environment

            self.isUpdating = true
            defer { self.isUpdating = false }

            if self.component == nil {
                editor.placeholders = RichTextEditorPlaceholders(body: environment.strings.RichText_PlaceholderBody, listEnd: "", listOutdent: "", pullQuote: environment.strings.RichText_PlaceholderQuote, blockQuote: environment.strings.RichText_PlaceholderQuote, codeBlock: environment.strings.RichText_PlaceholderCode, codeLanguage: environment.strings.RichText_PlaceholderCodeLanguage, detailsTitle: environment.strings.RichText_PlaceholderDetailTitle, quoteAuthor: environment.strings.RichText_PlaceholderQuoteAuthor, caption: environment.strings.RichText_PlaceholderCaption)
                editor.editMenuStrings = RichTextEditorMenuStrings(
                    format: environment.strings.TextFormat_Format,
                    bold: environment.strings.TextFormat_Bold,
                    italic: environment.strings.TextFormat_Italic,
                    underline: environment.strings.TextFormat_Underline,
                    lookUp: environment.strings.Conversation_ContextMenuLookUp,
                    translate: environment.strings.Conversation_ContextMenuTranslate,
                    share: environment.strings.Conversation_ContextMenuShare
                )
                
                // The screen paints `list.plainBackgroundColor` (below); clear the editor's opaque default
                // `.systemBackground` so that themed surface shows through.
                editor.canvasBackgroundColor = .clear
                // Theme the editor's mapper BEFORE seeding the document: the document setter builds each
                // block's attributed string with the mapper's current theme (baking in the foreground
                // color), and the `editor.theme` setter only re-maps existing boxes when `bounds.width > 0`
                // — which is false here (the editor frame is set later this pass). So seeding pre-existing
                // text before theming left it the `.default` black foreground. (The guarded re-apply below
                // is a no-op on this first pass since `appliedTheme` is now set, and handles later theme
                // changes when the frame — and a working reload width — exists.)
                editor.theme = Self.mapEditorTheme(environment.theme)
                // Lay text out with the exact numbers the recipient's renderer will use. This document is
                // sent as a rich message, so the counterpart surface is the chat bubble — the same metrics
                // the composer uses. Set alongside `theme` and BEFORE `editor.document`, per the
                // host-ordering invariant: the document setter bakes the current mapper into each block's
                // attributed string.
                editor.renderMetrics = InstantPageTheme.chatMessageRenderMetrics()
                self.appliedTheme = environment.theme
                // Quote geometry for the full-page article editor. Defaults == the editor's built-in look;
                // tune here to diverge from the chat composer.
                editor.quoteStyle = QuoteStyle(leadingInset: 9.0, topInset: 4.0, bottomInset: 4.0)
                editor.pullQuoteStyle = PullQuoteStyle()
                // Quote collapse/expand affordance icons (same assets as the chat composer / legacy input).
                if let collapse = UIImage(bundleImageName: "Media Gallery/Minimize")?.precomposed().withRenderingMode(.alwaysTemplate),
                   let expand = UIImage(bundleImageName: "Media Gallery/Fullscreen")?.precomposed().withRenderingMode(.alwaysTemplate) {
                    editor.quoteCollapseIcons = RichTextEditorQuoteCollapseIcons(collapse: collapse, expand: expand)
                }
                // Detail-block fold chevron — the same vertical arrow the InstantPage V2 renderer uses.
                editor.detailsChevronImage = UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow")?.withRenderingMode(.alwaysTemplate)
                // Markdown-on-paste: plain pasted text that parses as markdown with formatting/structure is
                // spliced as rich content instead of literal text. The parser is injected by the host (only
                // the monolith can reach the BrowserUI-backed markdown pipeline); nil falls back to the
                // editor's built-in plain-text paste.
                editor.plainTextFragmentTransformer = { [weak self] text in
                    guard let self, let component = self.component, let parser = component.pastedMarkdownParser, let content = parser(component.context, text) else {
                        return nil
                    }
                    return pasteFragmentDocument(fromChatInputContent: content)
                }
                // A selection-handle ("knob") drag must NOT be hijacked by the interactive keyboard-/modal-
                // dismiss gestures. These Display flags can only be set host-side (the editor package can't
                // import Display) and are applied to the hit-testable handle views, so the effect is scoped to
                // knob interaction — not the whole editor surface.
                editor.configureSelectionHandleView = { handle in
                    handle.disablesInteractiveTransitionGestureRecognizer = true   // navigation back-swipe (triggered by a horizontal knob drag)
                    handle.disablesInteractiveModalDismiss = true
                    handle.disablesInteractiveKeyboardGestureRecognizer = true
                }
                // Table row/column structural menu: the editor hands us a framework-agnostic descriptor; we
                // present it as a ContextController anchored to the tapped handle (in the editor's canvas).
                editor.onRequestTableStructuralMenu = { [weak self] request in
                    guard let self, let component = self.component else { return }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    presentTableStructuralMenu(request, presentationData: presentationData) { [weak self] controller in
                        self?.environment?.controller()?.presentInGlobalOverlay(controller)
                    }
                }
                // Media control (more button) menu: the editor hands us an account-free request; we present
                // our own menu anchored to the tapped control. `delete` is bound to the exact occurrence.
                editor.onRequestMediaControl = { [weak self] request in
                    guard let self, let component = self.component, let anchor = request.view else { return }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    switch request.control {
                    case .more:
                        var items: [ContextMenuItem] = []
                        items.append(.action(ContextMenuActionItem(
                            text: request.isSpoiler ? presentationData.strings.Attachment_DisableSpoiler : presentationData.strings.Attachment_EnableSpoiler,
                            icon: { _ in nil },
                            iconAnimation: ContextMenuActionItem.IconAnimation(name: "anim_spoiler", loop: true),
                            action: { _, f in f(.default); request.toggleSpoiler() }
                        )))
                        items.append(.action(ContextMenuActionItem(
                            text: presentationData.strings.Common_Delete,
                            textColor: .destructive,
                            icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) },
                            action: { _, f in f(.default); request.delete() }
                        )))
                        presentMediaControlMenu(anchorView: anchor, items: items,
                                                presentationData: presentationData) { [weak self] controller in
                            self?.environment?.controller()?.presentInGlobalOverlay(controller)
                        }
                    case .add:
                        guard let addMore = request.addMore else { break }
                        self.pickMedia(request: RichTextAttachmentScreen.MediaRequest(
                            imageOrVideo: RichTextAttachmentScreen.MediaRequest.ImageOrVideo(limit: 1),
                            music: false,
                            file: false,
                            location: false
                        )) { items in
                            guard let item = items.first, item.kind == .image || item.kind == .video else { return }   // mosaic is photo/video only
                            addMore(item.mediaID, item.naturalSize, item.kind)
                        }
                    case .delete:
                        request.delete()
                    case .toggleLayout:
                        request.toggleLayout?()
                    }
                }
                editor.disablesInteractiveTransitionGestureRecognizer = true   // navigation back-swipe (triggered by a horizontal knob drag)
                editor.disablesInteractiveModalDismiss = true
                editor.disablesInteractiveKeyboardGestureRecognizer = true
                // Seed the editor with the caller-supplied initial content (e.g. the chat composer's
                // current document when expanding); an empty document when none is provided.
                
                var initialContents: Document?
                var initialMedia: [String: Media] = [:]
                var initialEmojiFiles: [Int64: TelegramMediaFile] = [:]
                switch component.mode {
                case let .edit(documentValue, mediaValue, emojiFilesValue):
                    initialContents = documentValue
                    initialMedia = mediaValue
                    initialEmojiFiles = emojiFilesValue
                case let .standalone(documentValue, mediaValue, emojiFilesValue):
                    initialContents = documentValue
                    initialMedia = mediaValue
                    initialEmojiFiles = emojiFilesValue
                }
                
                editor.document = initialContents ?? Document()
                // Seed the picked-media store alongside the document (before the media-view provider runs)
                // so any media referenced by the initial document resolves on first layout.
                self.attachedMedia = initialMedia

                let emojiKeyboard = RichTextEmojiKeyboardController(context: component.context, editor: editor, requestLayout: { [weak self] in
                    guard let self, !self.isUpdating else { return }
                    self.componentState?.updated(transition: .spring(duration: 0.4))
                })
                self.emojiKeyboard = emojiKeyboard
                // Seed the keyboard's file store with the files of any custom emoji the initial document
                // references (the `Document` carries only fileIds) — before the editor's first layout, so a
                // custom emoji carried in from the chat composer renders, and its file survives back out.
                emojiKeyboard.seedEmojiFiles(initialEmojiFiles)

                // The host owns "(language, text) -> colours": `asyncStanaloneSyntaxHighlight` runs libprisma off
                // the main queue and returns the same cache model the message path stores, baking the LIGHT
                // palette — so what the editor shows is what the sent message will show. The editor cannot do
                // this itself; it cannot see TextFormat or libprisma.
                editor.registerSyntaxHighlighter { language, text, completion in
                    let spec = CachedMessageSyntaxHighlight.Spec(language: language, text: text)
                    let _ = (asyncStanaloneSyntaxHighlight(current: nil, specs: [spec])
                    |> deliverOnMainQueue).start(next: { result in
                        let entities = result.values[spec]?.entities ?? []
                        completion(entities.map { entity in
                            RichTextSyntaxToken(
                                range: NSRange(location: entity.range.lowerBound,
                                               length: entity.range.upperBound - entity.range.lowerBound),
                                color: UIColor(rgb: UInt32(bitPattern: entity.color)))
                        })
                    })
                }
                editor.registerEmojiViewProvider { [weak self] id, size in
                    return self?.emojiKeyboard?.customEmojiView(forId: id, size: size)
                }

                editor.registerFormulaRenderer { context in
                    guard let attachment = instantPageMathAttachment(
                        latex: context.latex,
                        fontSize: context.fontSize,
                        textColor: context.textColor,
                        mode: .inline
                    ) else {
                        return nil
                    }
                    return RichTextFormulaRenderResult(
                        image: attachment.rendered.image,
                        size: attachment.rendered.size,
                        ascent: attachment.rendered.ascent,
                        descent: attachment.rendered.descent
                    )
                }

                // A pill's type icon is also its geometry — an inline pill grows to hold it — so this
                // must be registered before the first reload, alongside the other providers.
                editor.registerButtonIconProvider(richTextEditorButtonIcon)

                editor.onEditFormulaRequested = { [weak self] latex, completion in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.presentFormulaEditor?(latex, { [weak self] updatedLatex in
                        completion(updatedLatex)
                        DispatchQueue.main.async { [weak self] in
                            self?.editor.becomeFirstResponder()
                        }
                    })
                }

                // Tapping EITHER pill kind opens the property sheet. `completion(nil)` deletes the pill —
                // and its row, when it was the last one.
                editor.onEditButtonRequested = { [weak self] button, isBlockPill, completion in
                    guard let self, let component = self.component else {
                        return
                    }
                    let controller = ButtonEditorScreen(context: component.context, button: button,
                                                        isBlockPill: isBlockPill) { [weak self] updated in
                        completion(updated)
                        DispatchQueue.main.async { [weak self] in
                            self?.editor.becomeFirstResponder()
                        }
                    }
                    self.environment?.controller()?.present(controller, in: .window(.root))
                }

                // The row's "…" menu: Add Button / Alignment (submenu) / Delete Row. Alignment uses the
                // project-standard `pushItems` submenu, exactly as the Add menu's Heading item does.
                editor.onRequestButtonRowMenu = { [weak self] request in
                    guard let self, let environment = self.environment, let component = self.component else {
                        return
                    }
                    let strings = environment.strings
                    var items: [ContextMenuItem] = []

                    items.append(.action(ContextMenuActionItem(text: strings.RichText_ButtonRowAdd, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                    }, action: { c, _ in
                        c?.dismiss(completion: nil)
                        request.addButton()
                    })))

                    items.append(.action(ContextMenuActionItem(text: strings.RichText_ButtonRowAlignment, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AlignVCenter"), color: theme.contextMenu.primaryColor)
                    }, action: { c, _ in
                        var subItems: [ContextMenuItem] = []
                        subItems.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Back, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                        }, iconPosition: .left, action: { c, _ in
                            c?.popItems()
                        })))
                        subItems.append(.separator)
                        let alignments: [(ButtonRowAlignment, String)] = [
                            (.justify, strings.RichText_ButtonRowAlignJustify),
                            (.left, strings.RichText_ButtonRowAlignLeft),
                            (.center, strings.RichText_ButtonRowAlignCenter),
                            (.right, strings.RichText_ButtonRowAlignRight),
                        ]
                        for (alignment, title) in alignments {
                            subItems.append(.action(ContextMenuActionItem(text: title, icon: { _ in nil },
                                additionalLeftIcon: { theme in
                                    return alignment == request.alignment
                                        ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                        : UIImage()
                                }, iconPosition: .left, action: { c, _ in
                                    c?.dismiss(completion: nil)
                                    request.setAlignment(alignment)
                                })))
                        }
                        c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                    })))

                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strings.RichText_ButtonRowDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { c, _ in
                        c?.dismiss(completion: nil)
                        request.deleteRow()
                    })))

                    // Anchor to the "…" rect, NOT to the editor view: `presentActionMenu` uses the whole
                    // source view as the reference, so passing `self.editor` positioned the menu against
                    // the entire editor and it landed offscreen. Same transient-anchor technique the
                    // table structural menu uses (`presentTableStructuralMenu`): a zero-interaction view
                    // at `request.sourceRect` inside the canvas, removed when the controller dismisses.
                    guard let anchorParent = request.view else {
                        return
                    }
                    guard let selfController = self.environment?.controller() else {
                        return
                    }
                    let anchor = UIView(frame: request.sourceRect)
                    anchor.isUserInteractionEnabled = false
                    anchorParent.addSubview(anchor)

                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    let controller = makeContextController(
                        presentationData: presentationData,
                        source: .reference(RichTextActionContextReferenceSource(sourceView: anchor, containerView: selfController.view, actionsPosition: .bottom)),
                        items: .single(ContextController.Items(content: .list(items))),
                        gesture: nil
                    )
                    controller.dismissed = { [weak anchor] in anchor?.removeFromSuperview() }
                    selfController.presentInGlobalOverlay(controller)
                }

                editor.registerMediaViewProvider { [weak self] items, _, displayMode, existing in
                    guard let self, let component = self.component else { return nil }
                    // Theme an audio row to the editor's accent/text scheme (same `list.item*` sources as
                    // `mapEditorTheme` / the table); ignored for image/map media.
                    let theme = component.context.sharedContext.currentPresentationData.with { $0 }.theme
                    let audioColors = InstantPageAudioColorOverride(
                        control: theme.list.itemAccentColor,
                        controlForeground: theme.list.itemCheckColors.foregroundColor,
                        title: theme.list.itemPrimaryTextColor,
                        description: theme.list.itemSecondaryTextColor
                    )
                    // Same `list.item*` sources as the audio row; ignored for image/map media.
                    let documentColors = InstantPageDocumentColorOverride(
                        control: theme.list.itemAccentColor,
                        controlForeground: theme.list.itemCheckColors.foregroundColor,
                        title: theme.list.itemPrimaryTextColor,
                        description: theme.list.itemSecondaryTextColor
                    )
                    let resolved: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)] = items.compactMap { item in
                        guard let media = self.attachedMedia[item.mediaID] else { return nil }
                        return (EngineMedia(media), item.naturalSize, item.isSpoiler, item.kind)
                    }
                    guard !resolved.isEmpty else { return nil }
                    // In-place update: reuse the existing container (surviving photo/video cells keep their bound
                    // fetch, no re-flash) across add-more / delete-one; else build a fresh one.
                    if let view = existing as? MediaItemNodeView {
                        view.updateResolvedItems(resolved, displayMode: displayMode)
                        return view
                    }
                    return MediaItemNodeView(context: component.context, items: resolved,
                                             audioColorOverride: audioColors,
                                             documentColorOverride: documentColors,
                                             displayMode: displayMode)
                }

                // Host the checklist checkbox with a `CheckNode` themed from the standard app checkbox palette
                // (`list.itemCheckColors`), mirroring `instantPageChecklistMarkerTheme`. Reads `appliedTheme`
                // (the live `PresentationTheme`) lazily; nil before the first theme apply (harmless — the editor
                // falls back to its glyph marker until a checkbox is provided).
                editor.registerChecklistMarkerViewProvider { [weak self] checked, _ in
                    guard let self, let theme = self.appliedTheme else { return nil }
                    let c = theme.list.itemCheckColors
                    let nodeTheme = CheckNodeTheme(backgroundColor: c.fillColor, strokeColor: c.foregroundColor, borderColor: c.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false)
                    return HostChecklistCheckboxView(theme: nodeTheme, checked: checked)
                }

                editor.onBecameFirstResponder = { [weak self] in
                    guard let self else {
                        return
                    }
                    if let controller = self.environment?.controller() as? RichTextAttachmentScreen {
                        controller.requestAttachmentMenuExpansion()
                    }
                }

                // The editor no longer drives its own layout/keyboard insets; it just tells us when anything
                // changes so we re-run this update (which calls editor.update(size:insets:)). The isUpdating
                // guard only defends the SYNCHRONOUS loop (update → editor.update → onChange → update);
                // editor.update/performLayout don't fire onChange synchronously, so it can't loop. Async
                // onChange (user edits/caret moves) skips the guard and correctly schedules a re-layout.
                editor.onChange = { [weak self] in
                    guard let self, !self.isUpdating else { return }
                    self.componentState?.updated(transition: .spring(duration: 0.4))
                    self.reconcilePreupload()
                }

                self.addSubview(editor)
                self.topEdgeEffectView.isUserInteractionEnabled = false
                self.addSubview(self.topEdgeEffectView)
            }
            self.component = component

            let isSendRichFormattingLocked = self.isSendRichFormattingLocked
            if !self.didShowPremiumToast && isSendRichFormattingLocked {
                self.didShowPremiumToast = true
                DispatchQueue.main.async { [weak self] in
                    self?.presentPremiumToast()
                }
            }

            if self.appliedTheme !== environment.theme {
                self.appliedTheme = environment.theme
                self.editor.theme = Self.mapEditorTheme(environment.theme)
            }

            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            
            let editorState = self.editor.currentState()
            
            if self.navigationTapView.superview == nil {
                component.overNavigationContainer.addSubview(self.navigationTapView)
            }
            transition.setFrame(view: self.navigationTapView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: environment.navigationHeight)))
            
            let leftNavActionsBarSize = self.leftNavActionsBar.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Navigation/Close"), action: { [weak self] in
                            guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                                return
                            }
                            controller.close()
                        })
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: barButtonSize.height)
            )
            let leftNavActionsBarFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: leftNavActionsBarSize)
            if let leftNavActionsBarView = self.leftNavActionsBar.view {
                if leftNavActionsBarView.superview == nil {
                    component.overNavigationContainer.addSubview(leftNavActionsBarView)
                }
                transition.setFrame(view: leftNavActionsBarView, frame: leftNavActionsBarFrame)
            }
            
            let rightNavActionsBarSize = self.rightNavActionsBar.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Media Editor/Undo"), action: editorState.canUndo ? { [weak self] in
                            self?.editor.undo()
                        } : nil),
                        GlassControlGroupComponent.Item(id: 1, content: .icon("Media Editor/Redo"), action: editorState.canRedo ? { [weak self] in
                            self?.editor.redo()
                        } : nil)
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: barButtonSize.height)
            )
            let rightNavActionsBarFrame = CGRect(origin: CGPoint(x: availableSize.width - (environment.safeInsets.left + 16.0) - rightNavActionsBarSize.width, y: 16.0), size: rightNavActionsBarSize)
            if let rightNavActionsBarView = self.rightNavActionsBar.view {
                if rightNavActionsBarView.superview == nil {
                    component.overNavigationContainer.addSubview(rightNavActionsBarView)
                }
                transition.setFrame(view: rightNavActionsBarView, frame: rightNavActionsBarFrame)
            }

            if case .standalone = component.mode {
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.RichText_TitleArticle,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            ))
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 40.0)
                )
                // The title is centered, but must clear both the left button cluster (Close + undo + redo) and the
                // Done button. When the natural center would overlap either side, re-center it in the gap between
                // the cluster's trailing edge and Done (needed on narrow screens where the centered title would
                // otherwise sit under the redo pill).
                let leftClusterMaxX = leftNavActionsBarFrame.maxX
                var titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
                if titleFrame.minX < leftClusterMaxX + 16.0 || titleFrame.maxX > rightNavActionsBarFrame.minX - 16.0 {
                    titleFrame.origin.x = leftClusterMaxX + floorToScreenPixels((rightNavActionsBarFrame.minX - leftClusterMaxX) - titleSize.width) / 2.0
                }
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        component.overNavigationContainer.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: titleFrame)
                }
            }
            
            self.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor

            let emojiPanelHeight = self.emojiKeyboard?.updatePanel(container: self, availableSize: availableSize, environment: environment, transition: transition) ?? 0.0
            let editorTop = environment.navigationHeight
            let editorFrame = CGRect(x: environment.safeInsets.left, y: 0.0,
                                     width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right,
                                     height: availableSize.height)
            self.editor.frame = editorFrame
            
            var barActions: [RichTextActionBarComponent.Action] = []
            let barActionsId: AnyHashable
            
            if editorState.hasSelection {
                barActionsId = 1
                
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("bold"), icon: "RichText/ToolBold",
                    action: { [weak self] _ in self?.editor.toggleBold() },
                    isSelected: editorState.bold
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("italic"), icon: "RichText/ToolItalic",
                    action: { [weak self] _ in self?.editor.toggleItalic() },
                    isSelected: editorState.italic
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("strike"), icon: "RichText/ToolStrike",
                    action: { [weak self] _ in self?.editor.toggleStrikethrough() },
                    isSelected: editorState.strikethrough
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("underline"), icon: "RichText/ToolUnderline",
                    action: { [weak self] _ in self?.editor.toggleUnderline() },
                    isSelected: editorState.underline
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("spoiler"), icon: "RichText/ToolSpoiler",
                    action: { [weak self] _ in self?.editor.toggleSpoiler() },
                    isSelected: editorState.spoiler
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("link"), icon: "RichText/ToolLink",
                    action: editorState.hasSelection ? { [weak self] _ in self?.presentLinkPrompt() } : nil,
                    isSelected: editorState.link != nil
                ))
                // A list/quote/etc. marker can only apply to paragraph text, so offer it only when the selection
                // covers no media or table block (see `EditorState.selectionIsTextOnly`).
                if editorState.selectionIsTextOnly {
                    barActions.append(RichTextActionBarComponent.Action(
                        id: AnyHashable("list"), icon: "RichText/ToolList",
                        action: { [weak self] sourceView in self?.presentListMenu(from: sourceView) },
                        isSelected: editorState.listMarker != nil,
                        showsPremiumBadge: !component.context.isPremium
                    ))
                    
                    barActions.append(RichTextActionBarComponent.Action(
                        id: AnyHashable("quote"), icon: "RichText/ToolQuote",
                        action: { [weak self] sourceView in self?.presentAddMenu(from: sourceView) },
                        isSelected: editorState.listMarker != nil,
                        showsPremiumBadge: !component.context.isPremium
                    ))
                }
            } else {
                barActionsId = 0
                
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("add"), icon: "Chat/Context Menu/Add",
                    action: editorState.isInTable ? nil : { [weak self] sourceView in
                        self?.presentAddMenu(from: sourceView)
                    },
                    isSelected: false
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("list"), icon: "RichText/ToolList",
                    action: editorState.isInTable ? nil : { [weak self] sourceView in
                        self?.presentListMenu(from: sourceView)
                    },
                    isSelected: false,
                    showsPremiumBadge: !component.context.isPremium
                ))
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("table"), icon: "RichText/ToolTable",
                    action: { [weak self] sourceView in
                        guard let self, let environment = self.environment else { return }
                        var items: [ContextMenuItem] = []
                        if self.editor.currentState().isInTable {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_Table_Copy, icon: { _ in nil }, action: { [weak self] _, f in
                                f(.default)
                                self?.editor.copyCurrentTable()
                            })))
                            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_Table_ConvertToText, icon: { _ in nil }, action: { [weak self] _, f in
                                f(.default)
                                self?.editor.convertCurrentTableToText()
                            })))
                            // One state read for both items: `currentState()` walks the whole TableBlock.
                            let tableState = self.editor.currentState()
                            let tableIsCompact = tableState.isTableCompact
                            items.append(.action(ContextMenuActionItem(
                                text: tableIsCompact ? environment.strings.RichText_Menu_Table_CompactOff : environment.strings.RichText_Menu_Table_CompactOn,
                                icon: { _ in
                                    return nil
                                },
                                action: { [weak self] _, f in
                                    f(.default)
                                    self?.editor.toggleTableCompact()
                                })))
                            let tableIsBordered = tableState.isTableBordered
                            items.append(.action(ContextMenuActionItem(
                                text: tableIsBordered ? environment.strings.RichText_Menu_Table_BordersOff : environment.strings.RichText_Menu_Table_BordersOn,
                                icon: { _ in
                                    // No borders/grid asset exists in Images.xcassets; the sibling
                                    // Compact item is likewise icon-less. A made-up bundleImageName
                                    // would silently render nothing (UIImage returns nil).
                                    return nil
                                },
                                action: { [weak self] _, f in
                                    f(.default)
                                    self?.editor.toggleTableBordered()
                                })))
                            items.append(.action(ContextMenuActionItem(text: environment.strings.RichText_Menu_Table_Delete, textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                                f(.default); self?.editor.deleteTable()
                            })))
                        } else {
                            // No caret: drop the table at the document end (become FR + caret to end), not at
                            // the default offset-0 start. With a caret it inserts at the caret as before.
                            self.focusEditorAtDocumentEndIfNeeded(hasCursor: viewTreeContainsFirstResponder(view: self.editor))
                            self.editor.insertTable(rows: 2, cols: 2)
                        }
                        self.presentActionMenu(from: sourceView, items: items)
                    },
                    isSelected: false,
                    showsPremiumBadge: !component.context.isPremium
                ))
                if component.presentAttachmentMenu != nil {
                    barActions.append(RichTextActionBarComponent.Action(
                        id: AnyHashable("attach"), icon: "RichText/ToolAttach",
                        action: editorState.isInTable ? nil : { [weak self] _ in self?.presentImagePicker() },
                        isSelected: false
                    ))
                }
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("emoji"), icon: "RichText/ToolEmoji",
                    action: { [weak self] _ in self?.emojiKeyboard?.toggle() },
                    isSelected: self.emojiKeyboard?.isEmojiMode ?? false
                ))
            }
            
            let tabBarBottomInset = max(environment.inputHeight, emojiPanelHeight, environment.additionalInsets.bottom)
            
            var sideInset: CGFloat = 12.0
            if tabBarBottomInset <= 28.0 {
                sideInset = 20.0
            }
            
            let actionBarSpacing: CGFloat = 6.0
            
            let aiButtonSize = self.aiButton.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Chat/Input/Text/InputAIIcon"), action: { [weak self] in
                            Task { @MainActor in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                guard let controller = environment.controller() as? RichTextAttachmentScreen else {
                                    return
                                }
                                
                                // AI edit on the current selection: seed the edit screen with only the
                                // selected sub-document (partial table/image coverage expanded to the whole
                                // block, both directions) and replace that same range with the result. The
                                // gate is CONTENT-based (`ChatInputContent.isEmpty`), not text-based, so a
                                // selection covering only an image / empty-caption still enters here.
                                if let sel = self.editor.selectedGlobalRange() {
                                    let doc = self.editor.document
                                    let (lo, hi) = doc.expandingRangeOverNonTextBlocks(globalFrom: sel.from, globalTo: sel.to)
                                    let subDoc = doc.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
                                    let subContent = chatInputContent(fromDocument: subDoc, media: self.currentMedia, emojiFiles: self.currentEmojiFiles)
                                    if !subContent.isEmpty {
                                        let initialText = ComposedRichMessage.rich(instantPage: instantPage(from: subContent))
                                        let textProcessingScreen = await component.context.sharedContext.makeTextProcessingScreen(
                                            context: component.context,
                                            theme: environment.theme,
                                            mode: .edit(
                                                saveRestoreStateId: nil,
                                                completion: { [weak self] result in
                                                    guard let self else {
                                                        return
                                                    }
                                                    let content: ChatInputContent
                                                    switch result {
                                                    case let .rich(instantPage):
                                                        content = chatInputContent(fromInstantPage: instantPage)
                                                    case let .plain(text, entities):
                                                        content = chatInputContent(from: chatInputStateStringWithAppliedEntities(text, entities: entities))
                                                    case .empty:
                                                        // An empty result deletes the (expanded) selection.
                                                        self.editor.replaceRange(from: lo, to: hi, with: Document(blocks: []))
                                                        return
                                                    }
                                                    let (document, media, emojiFiles) = documentMediaAndEmoji(fromChatInputContent: content)
                                                    self.emojiKeyboard?.seedEmojiFiles(emojiFiles)
                                                    self.attachedMedia.merge(media) { _, new in new }
                                                    self.editor.replaceRange(from: lo, to: hi, with: document)
                                                },
                                                send: nil,
                                                sendContextActions: nil
                                            ),
                                            inputText: initialText,
                                            copyResult: nil,
                                            translateChat: nil
                                        )
                                        if let parentController = controller.parentController() {
                                            parentController.push(textProcessingScreen)
                                        } else {
                                            controller.push(textProcessingScreen)
                                        }
                                        return
                                    }
                                }

                                // No usable selection → generate content and insert it at the caret.
                                do {
                                    let textProcessingScreen = await component.context.sharedContext.makeTextProcessingScreen(
                                        context: component.context,
                                        theme: environment.theme,
                                        mode: .generate(
                                            completion: { [weak self] result in
                                                guard let self else {
                                                    return
                                                }
                                                let content: ChatInputContent
                                                switch result {
                                                case let .rich(instantPage):
                                                    content = chatInputContent(fromInstantPage: instantPage)
                                                case let .plain(text, entities):
                                                    content = chatInputContent(from: chatInputStateStringWithAppliedEntities(text, entities: entities))
                                                case .empty:
                                                    return
                                                }
                                                let (document, media, emojiFiles) = documentMediaAndEmoji(fromChatInputContent: content)
                                                self.emojiKeyboard?.seedEmojiFiles(emojiFiles)
                                                self.attachedMedia.merge(media) { _, new in new }
                                                self.editor.insertDocument(document)
                                            }
                                        ),
                                        inputText: .plain(text: "", entities: []),
                                        copyResult: nil,
                                        translateChat: nil
                                    )
                                    if let parentController = controller.parentController() {
                                        parentController.push(textProcessingScreen)
                                    } else {
                                        controller.push(textProcessingScreen)
                                    }
                                }
                            }
                        })
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            
            var isSendEnabled = true
            let content = chatInputContent(fromDocument: self.currentDocument, media: self.currentMedia, emojiFiles: self.currentEmojiFiles)
            if content.isEmptyWhitespaceTrimmed {
                isSendEnabled = false
            }
            
            let longPressSendAvailable = component.sendContextActions != nil && isSendEnabled && !isSendRichFormattingLocked
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(RichTextSendButtonComponent(
                    theme: environment.theme,
                    isEnabled: isSendEnabled,
                    isLocked: isSendRichFormattingLocked,
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                            return
                        }
                        controller.donePressed()
                    },
                    longPressAction: longPressSendAvailable ? { [weak self] in
                        guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                            return
                        }
                        controller.displayLongPressSendMenu(sourceSendButton: self.sendButtonExtractedContainer)
                    } : nil
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            
            let actionBarSize = self.actionBar.update(
                transition: transition,
                component: AnyComponent(RichTextActionBarComponent(
                    theme: environment.theme,
                    actionsId: barActionsId,
                    actions: barActions
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - (sideInset + environment.safeInsets.left) * 2.0 - actionBarSpacing * 2.0 - aiButtonSize.width - sendButtonSize.width, height: 44.0)
            )
            
            var bottomInset = max(environment.inputHeight, emojiPanelHeight, environment.safeInsets.bottom)
            
            let aiButtonFrame = CGRect(origin: CGPoint(x: sideInset + environment.safeInsets.left, y: availableSize.height - bottomInset - 6.0 - aiButtonSize.height), size: aiButtonSize)
            if let aiButtonView = self.aiButton.view {
                if aiButtonView.superview == nil {
                    self.addSubview(aiButtonView)
                }
                transition.setFrame(view: aiButtonView, frame: aiButtonFrame)
            }
            
            let sendButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - (sideInset + environment.safeInsets.left) - sendButtonSize.width, y: availableSize.height - bottomInset - 6.0 - sendButtonSize.height), size: sendButtonSize)
            if self.sendButtonExtractedContainer.superview == nil {
                self.addSubview(self.sendButtonExtractedContainer)
            }
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.sendButtonExtractedContainer.contentView.addSubview(sendButtonView)
                }
                sendButtonView.frame = CGRect(origin: CGPoint(), size: sendButtonFrame.size)
            }
            transition.setPosition(view: self.sendButtonExtractedContainer, position: sendButtonFrame.center)
            transition.setBounds(view: self.sendButtonExtractedContainer, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
            transition.setPosition(view: self.sendButtonExtractedContainer.contentView, position: CGPoint(x: sendButtonFrame.width * 0.5, y: sendButtonFrame.height * 0.5))
            transition.setBounds(view: self.sendButtonExtractedContainer.contentView, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
            
            let actionBarFrame = CGRect(origin: CGPoint(x: sideInset + environment.safeInsets.left + aiButtonSize.width + actionBarSpacing, y: availableSize.height - bottomInset - 6.0 - actionBarSize.height), size: actionBarSize)
            if let actionBarView = self.actionBar.view {
                if actionBarView.superview == nil {
                    self.addSubview(actionBarView)
                }
                transition.setFrame(view: actionBarView, frame: actionBarFrame)
            }
            bottomInset += 6.0 + actionBarSize.height + 6.0
            
            // The editor no longer tracks the keyboard; supply the bottom obstruction as a scroll inset.
            // Only one of (system keyboard / emoji panel) is up at a time (the emoji panel uses an
            // EmptyInputView, so inputHeight ≈ 0 while it shows); the home-indicator safe area is the floor.
            _ = self.editor.update(size: editorFrame.size,
                                   insets: UIEdgeInsets(top: editorTop, left: 0.0, bottom: bottomInset + 16.0, right: 0.0),
                                   contentMargins: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0))

            // Top edge effect (mirrors ComposePollScreen): a blurred gradient at the screen top that content
            // fades under. Content color = the screen background (themed list.plainBackgroundColor).
            let edgeEffectHeight: CGFloat = 88.0
            let topEdgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(content: environment.theme.actionSheet.opaqueItemBackgroundColor, blur: true, alpha: 1.0, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: transition)

            // While the emoji panel is up, hide the AttachmentController's bottom menu/tab bar so the
            // container collapses that panel and re-lays out this screen at full height — otherwise the
            // emoji panel renders behind the attachment menu (mirrors ComposePollScreen).
            let isTabBarVisible = !(self.emojiKeyboard?.isEmojiMode ?? false)
            if self.lastTabBarVisible != isTabBarVisible {
                self.lastTabBarVisible = isTabBarVisible
                if let controller = environment.controller() as? RichTextAttachmentScreen {
                    let tabBarTransition = transition.containedViewLayoutTransition
                    DispatchQueue.main.async { [weak controller] in
                        controller?.updateTabBarVisibility(isTabBarVisible, tabBarTransition)
                    }
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

@available(iOS 13.0, *)
private final class RichTextActionContextReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let containerView: UIView
    private let actionsPosition: ContextControllerReferenceViewInfo.ActionsPosition
    init(sourceView: UIView, containerView: UIView, actionsPosition: ContextControllerReferenceViewInfo.ActionsPosition = .top) {
        self.sourceView = sourceView
        self.containerView = containerView
        self.actionsPosition = actionsPosition
    }
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView,
            contentAreaInScreenSpace: self.containerView.convert(self.containerView.bounds, to: nil),
            insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0),
            actionsPosition: self.actionsPosition)
    }
}

/// The resource carrying a medium's main bytes — the one whose data is worth moving when a local
/// medium is promoted to its cloud twin.
private func preuploadPrimaryResource(_ media: Media) -> MediaResource? {
    if let image = media as? TelegramMediaImage {
        return largestImageRepresentation(image.representations)?.resource
    }
    if let file = media as? TelegramMediaFile {
        return file.resource
    }
    return nil
}
