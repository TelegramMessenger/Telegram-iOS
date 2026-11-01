import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import UniversalMediaPlayer
import SemanticStatusNode
import MusicAlbumArtResources
import PhotoResources

/// Optional per-element color override for an audio row. When non-nil, the node uses these instead of the
/// chat-message-bubble theme colors — used by the RichTextEditor's in-editor preview so an audio block tracks
/// the editor's accent/text scheme (the same `RichTextEditorTheme` accent the table reads) rather than the
/// outgoing-bubble palette. nil (real message rendering) leaves the bubble palette untouched.
public struct InstantPageAudioColorOverride: Equatable {
    public let control: UIColor          // play-button fill + streaming/progress ring
    public let controlForeground: UIColor // the play/pause glyph drawn on the accent fill
    public let title: UIColor            // line 1 (track title)
    public let description: UIColor      // line 2 (duration · performer)
    public init(control: UIColor, controlForeground: UIColor, title: UIColor, description: UIColor) {
        self.control = control
        self.controlForeground = controlForeground
        self.title = title
        self.description = description
    }
}

// Renders an InstantPage audio block to match the standard music message bubble
// (ChatMessageInteractiveFileNode, non-thumbnail/non-voice music branch). Visual only differs
// from the file node in that playback is driven by InstantPageMediaPlaylist (our `play` closure)
// rather than the peer-messages model. V1's InstantPageAudioNode is unaffected.
final class InstantPageV2AudioContentNode: ASDisplayNode {
    private let context: AccountContext
    private let message: MessageReference?
    private let file: TelegramMediaFile
    private let incoming: Bool
    // nil → chat-bubble palette (real messages); non-nil → editor accent/text override (see the struct).
    private let colorOverride: InstantPageAudioColorOverride?

    private let statusNode: SemanticStatusNode
    // The download badge (download arrow / progress ring) on the control's bottom-right, as a regular music
    // message draws it: made when there is something to show, faded out and dropped when there is not.
    private var streamingStatusNode: SemanticStatusNode?
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let tapView: UIView

    // TextNode (unlike ASTextNode) has no stored `attributedText`; the string is an argument to
    // `TextNode.asyncLayout`. Keep the current strings here and feed them in `updateLayout`.
    private var titleAttributedString: NSAttributedString?
    private var descriptionAttributedString: NSAttributedString?

    var play: () -> Void = {}
    var togglePlayPause: () -> Void = {}
    var fetch: () -> Void = {}
    var cancelFetch: () -> Void = {}

    private var resourceStatusDisposable: Disposable?
    // EngineMediaResourceStatus is the TelegramCore typealias for Postbox's MediaResourceStatus;
    // using it keeps this file off `import Postbox` (TelegramCore doesn't re-export Postbox).
    private var fetchStatus: EngineMediaResourceStatus?

    private var playbackStatusDisposable: Disposable?
    private(set) var isPlaying: Bool = false

    // Theme-refresh state. `incoming` is already a `let` stored above; `incomingValue` tracks the
    // last theme-update's incoming flag so `updatePresentationData` can guard on change.
    private var presentationData: PresentationData
    private var incomingValue: Bool

    private static let progressDiameter: CGFloat = 40.0
    // Shifted +9pt right of the original x=3 (→ 12); the Ø40 control is vertically centered in the
    // 44pt row (y = (44 − 40)/2 = 2).
    private static let progressOrigin = CGPoint(x: 12.0, y: 2.0)
    private static let controlAreaWidth: CGFloat = 12.0 + 40.0 + 8.0
    private static let normHeight: CGFloat = 44.0
    private static let streamingDiameter: CGFloat = 20.0

    init(context: AccountContext, message: MessageReference?, file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData, colorOverride: InstantPageAudioColorOverride? = nil) {
        self.context = context
        self.message = message
        self.file = file
        self.incoming = incoming
        self.presentationData = presentationData
        self.incomingValue = incoming
        self.colorOverride = colorOverride

        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing

        let controlColors = InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: messageTheme.mediaActiveControlColor, incoming: incoming, colorOverride: colorOverride)

        var title: String?
        var performer: String?
        for attribute in file.attributes {
            if case let .Audio(_, _, t, p, _) = attribute { title = t; performer = p; break }
        }
        let albumArtImage: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        if file.isMusic, file.fileName?.lowercased().hasSuffix(".ogg") != true, let message = message {
            let fileRef: FileMediaReference = .message(message: message, media: file)
            albumArtImage = playerAlbumArt(
                engine: context.engine,
                fileReference: fileRef,
                albumArt: SharedMediaPlaybackAlbumArt(
                    thumbnailResource: ExternalMusicAlbumArtResource(file: fileRef, title: title ?? "", performer: performer ?? "", isThumbnail: true),
                    fullSizeResource: ExternalMusicAlbumArtResource(file: fileRef, title: title ?? "", performer: performer ?? "", isThumbnail: false)
                ),
                thumbnail: true,
                overlayColor: UIColor(white: 0.0, alpha: 0.3),
                drawPlaceholderWhenEmpty: false,
                attemptSynchronously: false
            )
        } else {
            albumArtImage = nil
        }

        self.statusNode = SemanticStatusNode(
            backgroundNodeColor: controlColors.background,
            foregroundNodeColor: controlColors.foreground,
            image: albumArtImage,
            overlayForegroundNodeColor: colorOverride?.controlForeground ?? presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor
        )

        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false

        self.tapView = UIView()

        super.init()

        self.titleAttributedString = InstantPageV2AudioContentNode.titleString(file: file, incoming: incoming, presentationData: presentationData, overrideColor: colorOverride?.title)
        self.descriptionAttributedString = InstantPageV2AudioContentNode.descriptionString(file: file, incoming: incoming, presentationData: presentationData, overrideColor: colorOverride?.description)

        self.addSubnode(self.statusNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)

        self.statusNode.transitionToState(.play, animated: false)

        if let messageId = self.message?.id {
            self.resourceStatusDisposable = (messageMediaFileStatus(context: context, messageId: messageId, file: file)
            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                guard let self else { return }
                // The first status only places the badge; later ones animate it.
                let animated = self.fetchStatus != nil
                self.fetchStatus = status
                self.updateStreamingState(animated: animated)
            })
        }
    }

    override func didLoad() {
        super.didLoad()
        // Tap target = plain view + UITapGestureRecognizer, NOT an ASControl: ASControl
        // .touchUpInside is cancelled by the chat ListView's gesture system (see InstantPageAudioNode
        // for the same reason).
        self.view.addSubview(self.tapView)
        self.tapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        // A tap on a shown badge goes to the badge (ChatMessageInteractiveFileNode's `fileTap`), anything else to the row.
        let badgeFrame = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: InstantPageV2AudioContentNode.controlFrame)
        let onBadge = self.streamingStatusNode != nil && badgeFrame.contains(recognizer.location(in: self.view))
        self.perform(InstantPageV2AudioContentNode.tapAction(fetchStatus: self.fetchStatus, isPlaying: self.isPlaying, onBadge: onBadge))
    }

    func controlTapped() {
        self.perform(InstantPageV2AudioContentNode.tapAction(fetchStatus: self.fetchStatus, isPlaying: self.isPlaying, onBadge: false))
    }

    enum TapAction: Equatable {
        case fetch
        case cancelFetch
        case play
        case togglePlayPause
    }

    // The badge cancels a running download (its ✕) or starts one (its arrow), as a regular music message's
    // `cacheProgressPressed` does; the rest of the row fetches a remote file and otherwise plays or toggles.
    static func tapAction(fetchStatus: EngineMediaResourceStatus?, isPlaying: Bool, onBadge: Bool) -> TapAction {
        if onBadge {
            switch fetchStatus {
            case .Fetching:
                return .cancelFetch
            case .Remote, .Paused:
                return .fetch
            case .none, .Local:
                break
            }
        }
        switch fetchStatus {
        case .Remote, .Paused:
            return .fetch
        case .none, .Local, .Fetching:
            return isPlaying ? .togglePlayPause : .play
        }
    }

    private func perform(_ action: TapAction) {
        switch action {
        case .fetch:
            self.fetch()
        case .cancelFetch:
            self.cancelFetch()
        case .play:
            self.play()
        case .togglePlayPause:
            self.togglePlayPause()
        }
    }

    deinit {
        self.resourceStatusDisposable?.dispose()
        self.playbackStatusDisposable?.dispose()
    }

    // Drives the big control's play/pause icon from the playlist state filtered to our
    // playlistId + itemId. Mirrors InstantPageAudioNode's subscription shape.
    func setPlaybackStatusSignal(_ signal: Signal<SharedMediaPlayerItemPlaybackState?, NoError>) {
        self.playbackStatusDisposable?.dispose()   // defensive: a re-call must not leak the prior subscription
        self.playbackStatusDisposable = (signal |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            guard let self else { return }
            let isPlaying = InstantPageV2AudioContentNode.isPlaying(state?.status.status)
            self.isPlaying = isPlaying
            self.statusNode.transitionToState(isPlaying ? .pause : .play)
            self.updateStreamingState(animated: true)
        })
    }

    // Buffering while playing counts as playing, as for a regular music message (FileMediaResourceStatus): a
    // stream catching up with its download keeps showing pause, without the badge coming back.
    static func isPlaying(_ status: MediaPlayerPlaybackStatus?) -> Bool {
        switch status {
        case .playing:
            return true
        case let .buffering(_, whilePlaying, _, _):
            return whilePlaying
        case .paused, .none:
            return false
        }
    }

    // Refreshes title/description attributed strings and the statusNode tint/foreground/overlay
    // colors when the theme or incoming direction changes. Called from the host view's
    // update(item:theme:renderContext:).
    func updatePresentationData(_ presentationData: PresentationData, incoming: Bool) {
        if self.presentationData.theme === presentationData.theme && self.incomingValue == incoming { return }
        self.presentationData = presentationData
        self.incomingValue = incoming
        self.titleAttributedString = InstantPageV2AudioContentNode.titleString(file: self.file, incoming: incoming, presentationData: presentationData, overrideColor: self.colorOverride?.title)
        self.descriptionAttributedString = InstantPageV2AudioContentNode.descriptionString(file: self.file, incoming: incoming, presentationData: presentationData, overrideColor: self.colorOverride?.description)
        let controlColors = self.currentControlColors()
        self.statusNode.backgroundNodeColor = controlColors.background
        // foreground/overlay also depend on incoming + theme (set at construction) — refresh them
        // too so the play glyph isn't miscolored after an in-place theme/direction change.
        self.statusNode.foregroundNodeColor = controlColors.foreground
        self.statusNode.overlayForegroundNodeColor = self.colorOverride?.controlForeground ?? presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor
        if let streamingStatusNode = self.streamingStatusNode {
            streamingStatusNode.backgroundNodeColor = controlColors.background
            streamingStatusNode.foregroundNodeColor = controlColors.foreground
        }

        // No setNeedsLayout(): this node doesn't override layout(); the host calls updateLayout(width:)
        // right after updatePresentationData, which re-runs the text layout with the rebuilt strings.
    }

    // The control's fill and glyph colours, shared by the play control and its download badge as in
    // ChatMessageInteractiveFileNode: an outgoing (or white) control cuts its glyph out, so the bubble shows through.
    static func controlColors(mediaActiveControlColor: UIColor, incoming: Bool, colorOverride: InstantPageAudioColorOverride?) -> (background: UIColor, foreground: UIColor) {
        let background = colorOverride?.control ?? mediaActiveControlColor
        let foreground: UIColor = colorOverride?.controlForeground ?? ((incoming && mediaActiveControlColor.rgb != 0xffffff) ? .white : .clear)
        return (background, foreground)
    }

    private func currentControlColors() -> (background: UIColor, foreground: UIColor) {
        let messageTheme = self.incomingValue ? self.presentationData.theme.chat.message.incoming : self.presentationData.theme.chat.message.outgoing
        return InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: messageTheme.mediaActiveControlColor, incoming: self.incomingValue, colorOverride: self.colorOverride)
    }

    // A regular music message's badge: download while remote, a thin ring while fetching, nothing once local
    // or while playing (the control then shows pause and the file streams).
    static func streamingState(fetchStatus: EngineMediaResourceStatus?, isPlaying: Bool) -> SemanticStatusNodeState {
        if isPlaying {
            return .none
        }
        switch fetchStatus {
        case .none, .Local:
            return .none
        case let .Fetching(_, progress):
            return .progress(value: CGFloat(max(progress, 0.027)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        case .Remote, .Paused:
            return .download
        }
    }

    // The badge sits on the control's bottom-right corner, 2pt past it (ChatMessageInteractiveFileNode's
    // `streamingCacheStatusFrame`).
    static func streamingBadgeFrame(controlFrame: CGRect) -> CGRect {
        let diameter = InstantPageV2AudioContentNode.streamingDiameter
        return CGRect(origin: CGPoint(x: controlFrame.maxX - diameter + 2.0, y: controlFrame.maxY - diameter + 2.0), size: CGSize(width: diameter, height: diameter))
    }

    // The ring cut out of the control around the badge, in the control's own coordinates.
    static func streamingBadgeCutout(controlFrame: CGRect) -> CGRect {
        let margin = 1.0 + UIScreenPixel
        return InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: controlFrame).offsetBy(dx: -controlFrame.minX, dy: -controlFrame.minY).insetBy(dx: -margin, dy: -margin)
    }

    private static var controlFrame: CGRect {
        return CGRect(origin: InstantPageV2AudioContentNode.progressOrigin, size: CGSize(width: InstantPageV2AudioContentNode.progressDiameter, height: InstantPageV2AudioContentNode.progressDiameter))
    }

    // Mirrors ChatMessageInteractiveFileNode's streaming badge handling: the badge appears in the control's
    // colours (at once; the cutout animates), fades out when there is nothing to show, and the control
    // carries a cutout ring while it is there.
    private func updateStreamingState(animated: Bool) {
        let streamingState = InstantPageV2AudioContentNode.streamingState(fetchStatus: self.fetchStatus, isPlaying: self.isPlaying)
        let controlFrame = InstantPageV2AudioContentNode.controlFrame

        if streamingState != .none && self.streamingStatusNode == nil {
            let controlColors = self.currentControlColors()
            let streamingStatusNode = SemanticStatusNode(backgroundNodeColor: controlColors.background, foregroundNodeColor: controlColors.foreground)
            streamingStatusNode.isUserInteractionEnabled = false
            streamingStatusNode.frame = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: controlFrame)
            self.insertSubnode(streamingStatusNode, aboveSubnode: self.statusNode)
            self.streamingStatusNode = streamingStatusNode
        }

        if let streamingStatusNode = self.streamingStatusNode {
            if streamingState == .none {
                self.streamingStatusNode = nil
                if animated {
                    streamingStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak streamingStatusNode] _ in
                        streamingStatusNode?.removeFromSupernode()
                    })
                } else {
                    streamingStatusNode.removeFromSupernode()
                }
            } else {
                streamingStatusNode.transitionToState(streamingState, animated: animated)
            }
        }

        if streamingState == .none {
            self.statusNode.setCutout(nil, animated: animated)
        } else {
            self.statusNode.setCutout(InstantPageV2AudioContentNode.streamingBadgeCutout(controlFrame: controlFrame), animated: animated)
        }
    }

    // Line 1: track title at 17pt (= baseDisplaySize at the default font setting; scales with it).
    private static func titleString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData, overrideColor: UIColor? = nil) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let titleFont = Font.regular(floor(presentationData.chatFontSize.baseDisplaySize * 17.0 / 17.0))
        var title = file.fileName ?? "Unknown Track"
        for attribute in file.attributes {
            if case let .Audio(false, _, t, _, _) = attribute { title = t ?? title; break }
        }
        return NSAttributedString(string: title, font: titleFont, textColor: overrideColor ?? messageTheme.fileTitleColor)
    }

    // Line 2: "<duration> · <performer>" at 15pt (omits the "· performer" tail when there's no
    // performer; omits the duration when it's absent).
    private static func descriptionString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData, overrideColor: UIColor? = nil) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let descriptionFont = Font.with(size: floor(presentationData.chatFontSize.baseDisplaySize * 15.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
        var performer = ""
        var durationSeconds: Int = 0
        for attribute in file.attributes {
            if case let .Audio(false, duration, _, p, _) = attribute {
                performer = (p ?? "").trimmingCharacters(in: .whitespaces)
                durationSeconds = duration
                break
            }
        }
        var text = ""
        if durationSeconds > 0 {
            text = String(format: "%d:%02d", Int32(durationSeconds / 60), Int32(durationSeconds % 60))
        }
        if !performer.isEmpty {
            text += text.isEmpty ? performer : " · \(performer)"
        }
        return NSAttributedString(string: text, font: descriptionFont, textColor: overrideColor ?? messageTheme.fileDescriptionColor)
    }

    func updateLayout(width: CGFloat) {
        let progressFrame = InstantPageV2AudioContentNode.controlFrame
        self.statusNode.frame = progressFrame
        self.streamingStatusNode?.frame = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: progressFrame)

        let controlAreaWidth = InstantPageV2AudioContentNode.controlAreaWidth
        let textWidth = max(1.0, width - controlAreaWidth - 8.0)
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: self.titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (descLayout, descApply) = TextNode.asyncLayout(self.descriptionNode)(TextNodeLayoutArguments(attributedString: self.descriptionAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleApply()
        let _ = descApply()

        let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descLayout.size.height
        let normHeight = InstantPageV2AudioContentNode.normHeight
        let titleFrame = CGRect(origin: CGPoint(x: controlAreaWidth, y: floor((normHeight - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
        self.titleNode.frame = titleFrame
        self.descriptionNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descLayout.size)

        // No scrubber. The tapView covers the full row so a tap anywhere toggles playback (there is
        // no scrubber pan to conflict with anymore).
        self.tapView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: normHeight))
    }
}
