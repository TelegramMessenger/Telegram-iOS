import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData

/// A self-contained, host-embeddable view that renders ONE standalone audio file (music or voice) as a
/// playable music/voice row, mirroring `StandaloneInstantPageImageView`. Built for the RichTextEditor,
/// which shows a freshly-picked (or edit-loaded) audio file outside any web page / message. Playback runs
/// through the shared `mediaManager` against a single-item, file-id-keyed `InstantPageMediaPlaylist` (each
/// view plays independently; document-wide sequential play is deferred). The underlying
/// `InstantPageV2AudioContentNode` is music-styled today, so a voice file renders as a music-style row
/// (waveform deferred); playback still uses the `.voice` player type.
@available(iOS 13.0, *)
public final class StandaloneInstantPageAudioView: UIView {
    private let audioNode: InstantPageV2AudioContentNode

    public init(context: AccountContext, file: TelegramMediaFile, colorOverride: InstantPageAudioColorOverride? = nil) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        // Authoring: always outgoing, no message reference. `colorOverride` (when the host supplies it) makes the
        // row track the editor's accent/text scheme instead of the outgoing-bubble palette (see the struct).
        self.audioNode = InstantPageV2AudioContentNode(context: context, message: nil, file: file, incoming: false, presentationData: presentationData, colorOverride: colorOverride)
        super.init(frame: .zero)
        self.addSubview(self.audioNode.view)

        // A synthetic, content-free webpage — the playlist only needs it for media-reference plumbing.
        let webpage = TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(
            url: "", displayUrl: "", hash: 0, type: nil, websiteName: nil, title: nil, text: nil,
            embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil,
            isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil,
            attributes: [], instantPage: nil)))
        // File-id-derived, stable playlist id so a re-layout doesn't reset playback state.
        let playlistId = InstantPageMediaPlaylistId.instantPage(webpageId: EngineMedia.Id(namespace: 0, id: file.fileId.id))
        let pageMedia = InstantPageMedia(index: 0, media: .file(file), url: nil, caption: nil, credit: nil)
        let playlistType: MediaManagerPlayerType = file.isVoice ? .voice : .music

        self.audioNode.play = {
            let playlist = InstantPageMediaPlaylist(playlistId: playlistId, webPage: webpage, messageReference: nil, items: [pageMedia], initialItemIndex: 0)
            context.sharedContext.mediaManager.setPlaylist((context, playlist), type: playlistType, control: .playback(.play))
        }
        self.audioNode.togglePlayPause = {
            context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: playlistType)
        }
        // Defensive hook, currently UNREACHED in this standalone view: `InstantPageV2AudioContentNode`
        // only invokes `fetch` from `controlTapped` when its `fetchStatus` is non-nil, and `fetchStatus`
        // is populated only when constructed with a non-nil `message` (we pass `message: nil`). Actual
        // resource fetching is done by the universal media player itself on `play` (it fetches the playlist
        // item automatically), so both a freshly-picked local file and an edit-loaded cloud audio play
        // without this closure. Kept (using the message-free `.standalone(media:)` reference) so the node's
        // fetch path is wired correctly should a future change start surfacing `fetchStatus` here.
        self.audioNode.fetch = {
            let _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file)).startStandalone()
        }
        let stateSignal = context.sharedContext.mediaManager.filteredPlaylistState(accountId: context.account.id, playlistId: playlistId, itemId: InstantPageMediaPlaylistItemId(index: 0), type: playlistType)
        self.audioNode.setPlaybackStatusSignal(stateSignal)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(size: CGSize) {
        self.audioNode.frame = CGRect(origin: .zero, size: size)
        self.audioNode.updateLayout(width: size.width)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.audioNode.frame = self.bounds
        self.audioNode.updateLayout(width: self.bounds.width)
    }
}
