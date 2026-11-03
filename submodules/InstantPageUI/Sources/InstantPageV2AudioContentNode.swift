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
    private let streamingStatusNode: SemanticStatusNode
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

    init(context: AccountContext, message: MessageReference?, file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData, colorOverride: InstantPageAudioColorOverride? = nil) {
        self.context = context
        self.message = message
        self.file = file
        self.incoming = incoming
        self.presentationData = presentationData
        self.incomingValue = incoming
        self.colorOverride = colorOverride

        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing

        let backgroundNodeColor = colorOverride?.control ?? messageTheme.mediaActiveControlColor
        let foregroundNodeColor: UIColor = colorOverride?.controlForeground ?? ((incoming && messageTheme.mediaActiveControlColor.rgb != 0xffffff) ? .white : .clear)

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
            backgroundNodeColor: backgroundNodeColor,
            foregroundNodeColor: foregroundNodeColor,
            image: albumArtImage,
            overlayForegroundNodeColor: colorOverride?.controlForeground ?? presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor
        )
        self.streamingStatusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: colorOverride?.control ?? messageTheme.mediaActiveControlColor)

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
        self.addSubnode(self.streamingStatusNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)

        self.statusNode.transitionToState(.play, animated: false)
        self.streamingStatusNode.transitionToState(.none, animated: false)

        if let messageId = self.message?.id {
            self.resourceStatusDisposable = (messageMediaFileStatus(context: context, messageId: messageId, file: file)
            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                self?.fetchStatus = status
                self?.updateStreamingState()
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

    @objc private func tapped() {
        self.controlTapped()
    }

    func controlTapped() {
        switch self.fetchStatus {
        case .Remote, .Paused:
            self.fetch()
        case .none, .Local, .Fetching:
            if self.isPlaying {
                self.togglePlayPause()
            } else {
                self.play()
            }
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
            let isPlaying: Bool
            if let status = state?.status {
                if case .playing = status.status {
                    isPlaying = true
                } else {
                    isPlaying = false
                }
            } else {
                isPlaying = false
            }
            self.isPlaying = isPlaying
            self.statusNode.transitionToState(isPlaying ? .pause : .play)
        })
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
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        self.statusNode.backgroundNodeColor = self.colorOverride?.control ?? messageTheme.mediaActiveControlColor
        // foreground/overlay also depend on incoming + theme (set at construction) — refresh them
        // too so the play glyph isn't miscolored after an in-place theme/direction change.
        self.statusNode.foregroundNodeColor = self.colorOverride?.controlForeground ?? ((incoming && messageTheme.mediaActiveControlColor.rgb != 0xffffff) ? .white : .clear)
        self.statusNode.overlayForegroundNodeColor = self.colorOverride?.controlForeground ?? presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor

        // No setNeedsLayout(): this node doesn't override layout(); the host calls updateLayout(width:)
        // right after updatePresentationData, which re-runs the text layout with the rebuilt strings.
    }

    private func updateStreamingState() {
        let state: SemanticStatusNodeState
        switch self.fetchStatus {
        case .none, .Local:
            state = .none
        case let .Fetching(_, progress):
            state = .progress(value: CGFloat(max(progress, 0.027)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        case .Remote, .Paused:
            state = .download
        }
        self.streamingStatusNode.transitionToState(state)
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
        let progressFrame = CGRect(origin: InstantPageV2AudioContentNode.progressOrigin, size: CGSize(width: InstantPageV2AudioContentNode.progressDiameter, height: InstantPageV2AudioContentNode.progressDiameter))
        self.statusNode.frame = progressFrame
        let streamingDiameter: CGFloat = 24.0
        self.streamingStatusNode.frame = CGRect(origin: CGPoint(x: progressFrame.maxX - streamingDiameter + 2.0, y: progressFrame.maxY - streamingDiameter + 2.0), size: CGSize(width: streamingDiameter, height: streamingDiameter))

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
