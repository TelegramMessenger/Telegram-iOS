import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import SemanticStatusNode
import AppBundle
import PhotoResources

/// Editor-side colour override for a document row. nil → the chat-bubble palette (real messages);
/// non-nil → the host's accent/text scheme, so the row reads correctly inside the article editor or
/// the composer rather than in outgoing-bubble colours. Twin of `InstantPageAudioColorOverride`.
public struct InstantPageDocumentColorOverride: Equatable {
    public let control: UIColor           // status-control fill
    public let controlForeground: UIColor // the glyph drawn on the control fill
    public let title: UIColor             // line 1 (file name)
    public let description: UIColor       // line 2 (size · extension)
    public init(control: UIColor, controlForeground: UIColor, title: UIColor, description: UIColor) {
        self.control = control
        self.controlForeground = controlForeground
        self.title = title
        self.description = description
    }
}

/// Renders `InstantPageBlock.document` — a generic file row inside a rich message.
///
/// Mirrors `InstantPageV2AudioContentNode` (which itself deliberately re-implements
/// `ChatMessageInteractiveFileNode`'s music branch rather than reusing it), minus everything
/// audio-specific: no playback, no album art, no playlist state. Two lines — filename and
/// "<size> · <extension>" — beside a status control that downloads on tap.
///
/// Two modes. **Message** (the default): download / progress / cancel, and a tap on an already-local
/// file reports `openDocument`. **Authoring** (`isAuthoring`, the editor via
/// `StandaloneInstantPageDocumentView`): a static file glyph, no fetch subscription, inert tap.
final class InstantPageV2DocumentContentNode: ASDisplayNode {
    private let file: TelegramMediaFile
    // nil → chat-bubble palette (real messages); non-nil → host accent/text override (see the struct).
    private let colorOverride: InstantPageDocumentColorOverride?
    /// Authoring (editor) mode: the row shows a static file glyph, never fetches, and its tap is inert.
    /// Correct by construction — a freshly-picked file is already local, and an edit-loaded cloud file is
    /// re-sent BY REFERENCE through `richMessageContentToUpload`'s already-cloud fast path, so there is
    /// never anything to download while authoring.
    private let isAuthoring: Bool

    private let statusNode: SemanticStatusNode
    /// The file's own preview thumbnail, when it has one (PDFs and images picked from the Files tab carry a
    /// `previewRepresentation` — see `PollAttachmentScreen`'s picker). Sits UNDER `statusNode`, which stays
    /// as the download/progress overlay in message mode. nil when the file has no preview.
    private let iconNode: TransformImageNode?
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let tapView: UIView

    private var titleAttributedString: NSAttributedString?
    private var descriptionAttributedString: NSAttributedString?

    /// Invoked when the row is tapped while the file is not yet local.
    var fetch: () -> Void = {}
    /// Invoked when the row is tapped while a fetch is in flight.
    var cancelFetch: () -> Void = {}
    /// Invoked when the row is tapped while the file is already local. Wired only in message mode.
    var openDocument: () -> Void = {}

    /// Excludes the row's thumbnail from screenshots — see `InstantPageV2RenderContext.captureProtected`.
    /// Only the artwork is protected: the file name/size text is metadata, and the regular chat file
    /// bubble does not protect its label either.
    var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                self.iconNode?.captureProtected = self.captureProtected
            }
        }
    }

    private var resourceStatusDisposable: Disposable?
    private var fetchStatus: EngineMediaResourceStatus?
    /// The message this row's status is currently bound to, so `bindStatus` can no-op on an unchanged
    /// rebind (the reuse path calls it on every layout).
    private var boundMessageId: EngineMessage.Id??

    private static let progressDiameter: CGFloat = 40.0
    // Ø40 control vertically centred in the 52pt row: y = (52 − 40) / 2 = 6.
    private static let progressOrigin = CGPoint(x: 12.0, y: 6.0)
    private static let controlAreaWidth: CGFloat = 12.0 + 40.0 + 8.0
    private static let normHeight: CGFloat = 52.0

    init(context: AccountContext, message: MessageReference?, file: TelegramMediaFile, incoming: Bool,
         presentationData: PresentationData,
         colorOverride: InstantPageDocumentColorOverride? = nil,
         isAuthoring: Bool = false) {
        self.file = file
        self.colorOverride = colorOverride
        self.isAuthoring = isAuthoring

        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let backgroundNodeColor = colorOverride?.control ?? messageTheme.mediaActiveControlColor
        let foregroundNodeColor: UIColor
        if let colorOverride {
            foregroundNodeColor = colorOverride.controlForeground
        } else {
            foregroundNodeColor = (incoming && messageTheme.mediaActiveControlColor.rgb != 0xffffff) ? .white : .clear
        }

        // A file with its own preview shows that thumbnail instead of a flat accent disc. The picker
        // populates `previewRepresentations` for image/* and application/pdf; `image/*` is admitted even
        // without one because the file itself is renderable.
        let hasThumbnail = !file.previewRepresentations.isEmpty || file.immediateThumbnailData != nil || file.mimeType.hasPrefix("image/")
        self.iconNode = hasThumbnail ? TransformImageNode() : nil

        self.statusNode = SemanticStatusNode(
            // Over a thumbnail the control is a scrim, not the accent fill, so the artwork stays readable.
            backgroundNodeColor: hasThumbnail ? presentationData.theme.chat.message.mediaOverlayControlColors.fillColor : backgroundNodeColor,
            // …and the arrow/ring must be drawn ON that scrim. NOT `.clear`: `effectiveForegroundColor`
            // only falls back to `overlayForegroundNodeColor` when the status node owns a `backgroundImage`,
            // and ours is nil (the thumbnail is a separate sibling node) — so a clear foreground renders the
            // download arrow and the progress ring invisible over artwork.
            foregroundNodeColor: hasThumbnail ? presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor : foregroundNodeColor,
            image: nil,
            overlayForegroundNodeColor: presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor
        )

        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false

        self.tapView = UIView()

        super.init()

        self.titleAttributedString = InstantPageV2DocumentContentNode.titleString(file: file, incoming: incoming, presentationData: presentationData, colorOverride: colorOverride)
        self.descriptionAttributedString = InstantPageV2DocumentContentNode.descriptionString(file: file, incoming: incoming, presentationData: presentationData, colorOverride: colorOverride)

        // The thumbnail goes in FIRST so the status control overlays it.
        if let iconNode = self.iconNode {
            self.addSubnode(iconNode)
            // A message-mode file resolves through its message (file-reference refresh); an authoring row
            // has no message, so it reads the local/cloud resource standalone.
            let fileReference: FileMediaReference = message.flatMap { .message(message: $0, media: file) } ?? .standalone(media: file)
            iconNode.setSignal(chatMessageImageFile(account: context.account, userLocation: .other, fileReference: fileReference, thumbnail: true))
        }
        self.addSubnode(self.statusNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)

        // Derives the initial state from the mode, so an authoring row never flashes a download arrow.
        self.updateFetchState()

        if !isAuthoring {
            self.bindStatus(context: context, messageId: message?.id)
        }
    }

    /// (Re)subscribes the row's fetch status. Called at init AND from the item view's reuse path, because a
    /// message that was PENDING when this node was built (`MessageReference` is `.none` for a
    /// `Namespaces.Message.Local` id, so `message?.id` is nil) acquires a cloud id later — and without a
    /// rebind the row stays permanently statusless, which reads as a completely dead tap until the chat is
    /// reopened and the view rebuilt.
    func bindStatus(context: AccountContext, messageId: EngineMessage.Id?) {
        guard !self.isAuthoring else {
            return
        }
        if let boundMessageId = self.boundMessageId, boundMessageId == messageId {
            return   // already bound to this message; the reuse path calls us every layout
        }
        self.boundMessageId = .some(messageId)
        self.resourceStatusDisposable?.dispose()
        let statusSignal: Signal<EngineMediaResourceStatus, NoError>
        if let messageId {
            // Fetch-manager-backed: the only route that surfaces `.Fetching` and drives the progress ring.
            statusSignal = messageMediaFileStatus(context: context, messageId: messageId, file: self.file)
        } else {
            // No message id yet (a pending/local message). Fall back to the raw resource status so the row
            // still knows Local vs Remote — the sender's own just-attached file IS local, so its tap must
            // open rather than dead-end. Downloading is inherently unavailable here: without a message
            // there is no fetch-manager entry to key progress off.
            // `engine.resources.status` yields the `EngineMediaResource.FetchStatus` WRAPPER, not the
            // `EngineMediaResourceStatus` (= `MediaResourceStatus`) typealias this node stores — hence
            // `_asStatus()`, mirroring `FetchMediaUtils`.
            statusSignal = context.engine.resources.status(resource: EngineMediaResource(self.file.resource))
            |> map { $0._asStatus() }
        }
        self.resourceStatusDisposable = (statusSignal
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            self?.fetchStatus = status
            self?.updateFetchState()
        })
    }

    deinit {
        self.resourceStatusDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()
        // Plain view + UITapGestureRecognizer, NOT an ASControl: ASControl's .touchUpInside is
        // cancelled by the chat ListView's gesture system (same reason as the audio node).
        self.view.addSubview(self.tapView)
        self.tapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    @objc private func tapped() {
        if self.isAuthoring {
            return   // the editor handles taps itself (caret placement / tap-select)
        }
        // INVARIANT: the tap must do whatever the disc DEPICTS — this switch and `updateFetchState`'s
        // must partition `fetchStatus` identically, or the control lies about what tapping it will do.
        switch self.fetchStatus {
        case .Local:
            self.openDocument()
        case .Fetching:
            self.cancelFetch()
        case .Remote, .Paused, .none:
            // `.none` is "status not known YET" (the subscription is async, so this is the window right
            // after a bubble appears) — NOT "downloaded". `updateFetchState` draws a download arrow for it,
            // so the tap fetches. Treating `.none` as local opened an undownloaded file instead of
            // fetching it.
            self.fetch()
        }
    }

    /// The static glyph an authoring row shows in place of a fetch control.
    private static func fileGlyph(color: UIColor) -> UIImage? {
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/File"), color: color)
    }

    private func updateFetchState() {
        if self.isAuthoring {
            // No fetch affordance while authoring — see `isAuthoring`. With a thumbnail the artwork IS the
            // affordance, so the control is hidden entirely rather than scrimming it.
            if self.iconNode != nil {
                self.statusNode.isHidden = true
                return
            }
            let glyphColor = self.colorOverride?.controlForeground ?? .white
            if let glyph = InstantPageV2DocumentContentNode.fileGlyph(color: glyphColor) {
                self.statusNode.transitionToState(.customIcon(glyph))
            } else {
                self.statusNode.transitionToState(.none)
            }
            return
        }
        if self.iconNode != nil, case .Local = self.fetchStatus {
            // Downloaded and thumbnailed: show the artwork clean; the whole row is still tappable to open.
            self.statusNode.isHidden = true
            return
        }
        self.statusNode.isHidden = false
        let state: SemanticStatusNodeState
        switch self.fetchStatus {
        case .none:
            state = .download
        case .Local:
            // Downloaded: a static file glyph, tappable to open.
            if let glyph = InstantPageV2DocumentContentNode.fileGlyph(color: .white) {
                state = .customIcon(glyph)
            } else {
                state = .none
            }
        case let .Fetching(_, progress):
            state = .progress(value: CGFloat(max(progress, 0.027)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        case .Remote, .Paused:
            state = .download
        }
        self.statusNode.transitionToState(state)
    }

    // Line 1: filename at 17pt (= baseDisplaySize at the default font setting; scales with it).
    private static func titleString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData,
                                    colorOverride: InstantPageDocumentColorOverride?) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let titleFont = Font.regular(floor(presentationData.chatFontSize.baseDisplaySize))
        let title = file.fileName ?? "File"
        return NSAttributedString(string: title, font: titleFont,
                                  textColor: colorOverride?.title ?? messageTheme.fileTitleColor)
    }

    // Line 2: "<size> · <EXT>", omitting either part when unavailable.
    private static func descriptionString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData,
                                          colorOverride: InstantPageDocumentColorOverride?) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let descriptionFont = Font.with(size: floor(presentationData.chatFontSize.baseDisplaySize * 15.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])

        var text = ""
        if let size = file.size, size > 0 {
            text = dataSizeString(Int(size), formatting: DataSizeStringFormatting(presentationData: presentationData))
        }
        if let fileName = file.fileName, let dotIndex = fileName.lastIndex(of: "."), dotIndex < fileName.endIndex {
            let ext = String(fileName[fileName.index(after: dotIndex)...]).uppercased()
            if !ext.isEmpty {
                text += text.isEmpty ? ext : " · \(ext)"
            }
        }
        return NSAttributedString(string: text, font: descriptionFont,
                                  textColor: colorOverride?.description ?? messageTheme.fileDescriptionColor)
    }

    func updateLayout(width: CGFloat) {
        let progressFrame = CGRect(origin: InstantPageV2DocumentContentNode.progressOrigin, size: CGSize(width: InstantPageV2DocumentContentNode.progressDiameter, height: InstantPageV2DocumentContentNode.progressDiameter))
        self.statusNode.frame = progressFrame
        if let iconNode = self.iconNode {
            // The thumbnail fills the same Ø40 slot as the status disc, aspect-FILLED into a rounded square.
            // Deliberately the same slot (and so the same 52pt row) as a control-only document: `MediaBlockBox`
            // sizes the editor's row from `kind` alone — it cannot resolve the file — so a thumbnail-dependent
            // height would desync the editor preview from the V2 renderer.
            iconNode.frame = progressFrame
            let representationSize = largestImageRepresentation(self.file.previewRepresentations)?.dimensions.cgSize
                ?? CGSize(width: 320.0, height: 320.0)
            let apply = iconNode.asyncLayout()(TransformImageArguments(
                corners: ImageCorners(radius: 8.0),
                imageSize: representationSize.aspectFilled(progressFrame.size),
                boundingSize: progressFrame.size,
                intrinsicInsets: UIEdgeInsets()
            ))
            apply()
        }

        let controlAreaWidth = InstantPageV2DocumentContentNode.controlAreaWidth
        let textWidth = max(1.0, width - controlAreaWidth - 8.0)
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: self.titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (descLayout, descApply) = TextNode.asyncLayout(self.descriptionNode)(TextNodeLayoutArguments(attributedString: self.descriptionAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleApply()
        let _ = descApply()

        let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descLayout.size.height
        let normHeight = InstantPageV2DocumentContentNode.normHeight
        let titleFrame = CGRect(origin: CGPoint(x: controlAreaWidth, y: floor((normHeight - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
        self.titleNode.frame = titleFrame
        self.descriptionNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descLayout.size)

        self.tapView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: normHeight))
    }
}

/// Item view for `InstantPageBlock.document`. Mirrors `InstantPageV2MediaAudioView`'s shape: wraps a
/// content node, routes fetch through the fetch manager, and re-lays out on bounds change.
final class InstantPageV2DocumentView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2DocumentItem
    var itemFrame: CGRect { return self.item.frame }
    private let documentNode: InstantPageV2DocumentContentNode

    /// Set by the renderer; fires with this row's file when an already-downloaded file is tapped.
    /// LOAD-BEARING: must be re-wired in the renderer's REUSE arm too — a recycled view may have been
    /// created against a previous `InstantPageV2View`, and without re-wiring taps silently stop working
    /// after scrolling away and back (the same trap as `onButtonTapped`).
    var onDocumentTapped: ((TelegramMediaFile) -> Void)?

    /// The message the fetch/cancel closures and the status subscription are currently bound to, so the
    /// reuse path can detect a pending → confirmed transition and rebind.
    private var boundMessage: MessageReference?

    init(item: InstantPageV2DocumentItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        let presentationData = renderContext.context.sharedContext.currentPresentationData.with { $0 }
        let incoming = renderContext.message?.isIncoming == true
        let documentFile: TelegramMediaFile
        if case let .file(f) = item.media.media {
            documentFile = f
        } else {
            documentFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/octet-stream", size: nil, attributes: [], alternativeRepresentations: [])
        }
        self.documentNode = InstantPageV2DocumentContentNode(context: renderContext.context, message: renderContext.message, file: documentFile, incoming: incoming, presentationData: presentationData)

        super.init(frame: item.frame)
        self.backgroundColor = .clear
        self.addSubview(self.documentNode.view)

        self.documentNode.captureProtected = renderContext.captureProtected
        self.bindToMessage(renderContext: renderContext)
    }

    /// Binds every piece of message-dependent wiring: the fetch/cancel closures and the node's status
    /// subscription. **Must be re-applied from the reuse path**, not just at init: a message that was
    /// PENDING when this view was built carries a `MessageReference` of `.none` (see
    /// `MessageReference.init` — a `Namespaces.Message.Local` id is dropped), so its closures early-return
    /// and no status arrives. When the send confirms, the item view is REUSED rather than rebuilt, so
    /// without this the row stays wired to the pending message and its tap does nothing until the chat is
    /// reopened.
    private func bindToMessage(renderContext: InstantPageV2RenderContext) {
        let fetchContext = renderContext.context
        let fetchMessage = renderContext.message
        let fetchMedia = self.item.media
        self.boundMessage = fetchMessage
        self.documentNode.fetch = {
            guard case let .file(file) = fetchMedia.media, let message = fetchMessage, let messageId = message.id else {
                return
            }
            // Through the fetch manager, not freeMediaFileInteractiveFetched: messageMediaFileStatus
            // keys progress off the fetch manager's `hasEntry`, so only this route surfaces
            // .Fetching and drives the progress ring.
            let _ = messageMediaFileInteractiveFetched(fetchManager: fetchContext.fetchManager, messageId: messageId, messageReference: message, file: file, userInitiated: true, priority: .userInitiated).startStandalone()
        }
        self.documentNode.cancelFetch = {
            guard case let .file(file) = fetchMedia.media, let messageId = fetchMessage?.id else {
                return
            }
            messageMediaFileCancelInteractiveFetch(context: fetchContext, messageId: messageId, file: file)
        }
        self.documentNode.openDocument = { [weak self] in
            guard let self, case let .file(file) = fetchMedia.media else {
                return
            }
            self.onDocumentTapped?(file)
        }
        self.documentNode.bindStatus(context: fetchContext, messageId: fetchMessage?.id)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.documentNode.frame = self.bounds
        self.documentNode.updateLayout(width: self.bounds.width)
    }

    func update(item: InstantPageV2DocumentItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        self.item = item
        // Rebind when the message identity changed — the pending → confirmed transition arrives HERE (the
        // view is reused, not rebuilt), and it is what turns a dead tap into a working one.
        if self.boundMessage != renderContext.message {
            self.bindToMessage(renderContext: renderContext)
        }
        self.documentNode.captureProtected = renderContext.captureProtected
        self.documentNode.updateLayout(width: self.bounds.width)
    }

    // Not a gallery item: explicit no-op witnesses, matching the audio view's pattern.
    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
    }
}
