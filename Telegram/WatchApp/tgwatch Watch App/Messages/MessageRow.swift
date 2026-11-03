import Foundation
import TDShim

enum MessageRow: Identifiable, Equatable, Hashable {
    case bubble(MessageBubble)
    case service(ServiceLine)
    case daySeparator(DayLabel)
    case unreadDivider(afterMessageId: Int64)

    var id: String {
        switch self {
        case .bubble(let b):       return "msg-\(b.messageId)"
        case .service(let s):      return "svc-\(s.messageId)"
        case .daySeparator(let d): return "day-\(d.key)"
        case .unreadDivider(let id): return "unread-\(id)"
        }
    }
}

struct MessageBubble: Equatable, Hashable {
    let messageId: Int64
    let isOutgoing: Bool
    /// First name of the sender for incoming bubbles in groups; nil otherwise.
    let senderName: String?
    /// Body text — for text bubbles, the message body; for photo / video bubbles, the caption (may be "").
    let body: String
    /// Photo metadata for `messagePhoto` content; nil for non-photo bubbles.
    let photo: PhotoVisual?
    /// Video metadata for `messageVideo` content; nil for non-video bubbles.
    let video: VideoVisual?
    /// Round-video-note metadata for `messageVideoNote` content; nil otherwise.
    /// Mutually exclusive with `photo`, `video`, `sticker`.
    let videoNote: VideoNoteVisual?
    /// Voice-note metadata for `messageVoiceNote` content; nil otherwise.
    /// Mutually exclusive with `photo`, `video`, `videoNote`, `sticker`.
    let voiceNote: VoiceNoteVisual?
    /// Music / audio-file metadata for `messageAudio` content; nil otherwise.
    /// Mutually exclusive with `photo`, `video`, `videoNote`, `voiceNote`, `sticker`, `location`, `poll`.
    let audio: AudioVisual?
    let document: DocumentVisual?
    /// Sticker metadata for `messageSticker` content; nil for non-sticker bubbles.
    let sticker: StickerVisual?
    /// Location / venue metadata for `messageLocation` / `messageVenue` content; nil otherwise.
    /// Mutually exclusive with `photo`, `video`, `videoNote`, `voiceNote`, `audio`, `sticker`, `poll`.
    let location: LocationVisual?
    /// Poll / quiz metadata for `messagePoll` content; nil otherwise.
    /// Mutually exclusive with the other media fields.
    let poll: PollVisual?
    /// Delivery status of the message (pending / sent / failed).
    let sendingState: SendingState
    /// Reply header for messages that reply to another message; nil if not a reply.
    let replyHeader: ReplyHeader?
    /// Palette index for the sender-name label (incoming groups only); nil = uncolored.
    /// Set together with `senderName` — both nil for outgoing / private / non-user senders.
    var senderColorIndex: Int? = nil
    /// True for a sent outgoing message the recipient hasn't read yet (`id > lastReadOutboxMessageId`).
    var isUnreadOutgoing: Bool = false
    /// True for content with no dedicated bubble — renders the "Unsupported message"
    /// placeholder. Set from `isUnsupportedContent(msg.content)` in `messageRows`.
    var isUnsupported: Bool = false

    /// The delivery-status indicator to render for this bubble. Outgoing only;
    /// `isUnreadOutgoing` already encodes "sent, unread, not Saved Messages".
    var outgoingStatus: OutgoingStatus {
        guard isOutgoing else { return .none }
        switch sendingState {
        case .pending: return .pending
        case .failed:  return .failed
        case .sent:    return isUnreadOutgoing ? .unread : .none
        }
    }
}

/// Collapses an outgoing message's delivery state into the single indicator the
/// chat UI shows at the bubble's bottom-leading corner. Incoming messages — and
/// outgoing messages that are sent and already read — show nothing.
enum OutgoingStatus: Equatable {
    case none
    case pending
    case failed
    case unread
}

struct ServiceLine: Equatable, Hashable {
    let messageId: Int64
    let text: String
}

struct DayLabel: Equatable, Hashable {
    /// Stable per-day key (`yyyy-MM-dd` in the calendar's time zone) used for the row id.
    let key: String
    /// Human label (`Today`, `Yesterday`, `Sunday`, `May 5`, …).
    let label: String
}

/// Compacts cached messages into `[MessageRow]` for rendering. Sorts by `message.id`
/// ascending, prepends `.daySeparator` rows above each new day's first message,
/// and — when `unreadDividerAfterId` is set — interleaves a single `.unreadDivider`
/// row immediately before the first message with `id > unreadDividerAfterId`.
/// `selfUserId` is the authenticated user's id; used by service-line formatters to
/// produce the "You ..." actor prefix for actions the current user performed.
func messageRows(
    messages: [CachedMessage],
    userNames: [Int64: String],
    fileLocals: [Int: File] = [:],
    chatType: ChatType,
    chatId: Int64,
    today: Foundation.Date,
    calendar: Calendar,
    locale: Locale = .current,
    selfUserId: Int64? = nil,
    unreadDividerAfterId: Int64? = nil,
    lastReadOutboxMessageId: Int64 = 0
) -> [MessageRow] {
    let sorted = messages.sorted { $0.id < $1.id }
    let cacheById: [Int64: CachedMessage] = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })

    // Saved Messages (a private chat with our own user id) has no recipient, so
    // outgoing messages there are implicitly read — they never get the unread dot.
    let isSavedMessages: Bool = {
        guard let selfUserId, case .chatTypePrivate(let p) = chatType else { return false }
        return p.userId == selfUserId
    }()

    let dayKeyFormatter = DateFormatter()
    dayKeyFormatter.calendar = calendar
    dayKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
    dayKeyFormatter.timeZone = calendar.timeZone
    dayKeyFormatter.dateFormat = "yyyy-MM-dd"

    var rows: [MessageRow] = []
    var lastDayKey: String? = nil
    var dividerPlaced = false

    for msg in sorted {
        if let divider = unreadDividerAfterId, !dividerPlaced, msg.id > divider {
            // Anchor id need not be present in `messages` — divider position is
            // purely "before the first id > anchor", which lets it remain stable
            // even after older messages have been paginated out of the window.
            rows.append(.unreadDivider(afterMessageId: divider))
            dividerPlaced = true
        }
        let date = Foundation.Date(timeIntervalSince1970: TimeInterval(msg.date))
        let dayKey = dayKeyFormatter.string(from: date)
        if dayKey != lastDayKey {
            let label = daySeparatorLabel(for: date, today: today, calendar: calendar, locale: locale)
            rows.append(.daySeparator(.init(key: dayKey, label: label)))
            lastDayKey = dayKey
        }
        if let svc = serviceLineText(
            msg,
            selfUserId: selfUserId,
            userNames: userNames,
            messageCache: cacheById,
            includeActor: true,
            chatType: chatType
        ) {
            rows.append(.service(.init(messageId: msg.id, text: svc)))
            continue
        }
        let sender = senderLabel(for: msg, chatType: chatType, userNames: userNames)
        rows.append(.bubble(.init(
            messageId: msg.id,
            isOutgoing: msg.isOutgoing,
            senderName: sender?.name,
            body: messageBody(msg.content),
            photo: photoVisual(for: msg.content, fileLocals: fileLocals),
            video: videoVisual(for: msg.content, fileLocals: fileLocals),
            videoNote: videoNoteVisual(for: msg.content, fileLocals: fileLocals),
            voiceNote: voiceNoteVisual(for: msg.content, fileLocals: fileLocals),
            audio: audioVisual(for: msg.content, fileLocals: fileLocals),
            document: documentVisual(for: msg.content, fileLocals: fileLocals),
            sticker: stickerVisual(for: msg.content, fileLocals: fileLocals),
            location: locationVisual(
                for: msg.content,
                messageDate: Foundation.Date(
                    timeIntervalSince1970: TimeInterval(msg.editDate != 0 ? msg.editDate : msg.date)
                )
            ),
            poll: pollVisual(for: msg.content),
            sendingState: msg.sendingState,
            replyHeader: replyPreview(
                msg.replyTo,
                inChatId: chatId,
                isOutgoing: msg.isOutgoing,
                cache: cacheById,
                userNames: userNames
            ),
            senderColorIndex: sender?.colorIndex,
            isUnreadOutgoing: !isSavedMessages && msg.isOutgoing && msg.sendingState == .sent && msg.id > lastReadOutboxMessageId,
            isUnsupported: isUnsupportedContent(msg.content)
        )))
    }
    return rows
}

/// Builds a `PhotoVisual` for `messagePhoto` content, or returns `nil` for any other content
/// or when no displayable photo size is present. Looks up the chosen size's file id in
/// `fileLocals` for the freshest local-path snapshot, falling back to the static `File`
/// carried by the message itself when the store hasn't seen `updateFile` yet.
private func photoVisual(for content: MessageContent, fileLocals: [Int: File]) -> PhotoVisual? {
    guard case .messagePhoto(let m) = content else { return nil }
    guard let size = selectPhotoSize(m.photo.sizes) else { return nil }
    let fileId = size.photo.id
    let file = fileLocals[fileId] ?? size.photo
    let localPath: String? = (file.local.isDownloadingCompleted && !file.local.path.isEmpty) ? file.local.path : nil
    return PhotoVisual(
        fileId: fileId,
        width: size.width,
        height: size.height,
        minithumbnail: m.photo.minithumbnail?.data,
        localPath: localPath
    )
}

/// Builds a `VideoVisual` for `messageVideo` content, or returns `nil` for any other
/// content. Looks up the chosen quality's file id in `fileLocals` for the freshest
/// local-path snapshot of the video file, and the preview file id likewise for the
/// preview thumbnail. Both fall back to the static `File` carried by the message
/// itself when the store hasn't seen `updateFile` yet.
private func videoVisual(for content: MessageContent, fileLocals: [Int: File]) -> VideoVisual? {
    guard case .messageVideo(let m) = content else { return nil }
    let chosen = selectVideoQuality(primary: m.video, alternatives: m.alternativeVideos)
    let videoFile = fileLocals[chosen.file.id] ?? chosen.file
    let videoLocalPath: String? = (videoFile.local.isDownloadingCompleted && !videoFile.local.path.isEmpty)
        ? videoFile.local.path : nil

    var preview = selectVideoPreview(m)
    if let pid = preview.previewFileId, let pf = fileLocals[pid] ?? lookupStaticPreviewFile(in: m, id: pid) {
        let path: String? = (pf.local.isDownloadingCompleted && !pf.local.path.isEmpty) ? pf.local.path : nil
        preview = VideoPreview(
            previewFileId: preview.previewFileId,
            previewWidth: preview.previewWidth,
            previewHeight: preview.previewHeight,
            minithumbnail: preview.minithumbnail,
            previewLocalPath: path
        )
    }

    return VideoVisual(
        videoFileId: chosen.file.id,
        width: chosen.width,
        height: chosen.height,
        duration: m.video.duration,
        mimeType: chosen.mimeType,
        preview: preview,
        videoLocalPath: videoLocalPath
    )
}

/// Returns the message-embedded `File` snapshot for the given preview id when the
/// store hasn't yet seen an `updateFile` for it. Lets us read the static file id +
/// path even before the first download tick lands.
private func lookupStaticPreviewFile(in m: MessageVideo, id: Int) -> File? {
    if let cover = m.cover, let s = selectVideoCoverSize(cover.sizes), s.photo.id == id {
        return s.photo
    }
    if let thumb = m.video.thumbnail, thumb.file.id == id {
        return thumb.file
    }
    return nil
}

/// Builds a `VideoNoteVisual` for `messageVideoNote` content, or returns `nil` for
/// any other content. Looks up the playable file id and (optionally) the thumbnail
/// file id in `fileLocals` for the freshest local-path snapshot; both fall back to
/// the message-embedded `File` snapshot when the store hasn't seen `updateFile` yet.
private func videoNoteVisual(for content: MessageContent, fileLocals: [Int: File]) -> VideoNoteVisual? {
    guard case .messageVideoNote(let m) = content else { return nil }
    let videoFile = fileLocals[m.videoNote.video.id] ?? m.videoNote.video
    let videoLocalPath: String? = (videoFile.local.isDownloadingCompleted && !videoFile.local.path.isEmpty)
        ? videoFile.local.path : nil

    let thumbFileId = m.videoNote.thumbnail?.file.id
    var thumbLocalPath: String? = nil
    if let tid = thumbFileId {
        let tf = fileLocals[tid] ?? m.videoNote.thumbnail?.file
        if let tf, tf.local.isDownloadingCompleted, !tf.local.path.isEmpty {
            thumbLocalPath = tf.local.path
        }
    }
    return VideoNoteVisual(
        videoFileId: m.videoNote.video.id,
        length: m.videoNote.length,
        duration: m.videoNote.duration,
        thumbFileId: thumbFileId,
        minithumbnail: m.videoNote.minithumbnail?.data,
        thumbLocalPath: thumbLocalPath,
        videoLocalPath: videoLocalPath
    )
}

/// Builds a `VoiceNoteVisual` for `messageVoiceNote` content, or returns `nil`
/// for any other content. Looks up the voice file id in `fileLocals` for the
/// freshest local-path snapshot, falling back to the message-embedded `File`
/// when the store hasn't seen `updateFile` yet.
///
/// Internal (not private like its peers) so `VoiceNoteVisualTests` can exercise
/// the projection directly via `@testable import`. Consider moving these tests
/// behind `messageRows(...)` if direct access becomes a maintenance burden.
func voiceNoteVisual(for content: MessageContent, fileLocals: [Int: File]) -> VoiceNoteVisual? {
    guard case .messageVoiceNote(let m) = content else { return nil }
    let voiceFile = fileLocals[m.voiceNote.voice.id] ?? m.voiceNote.voice
    let localPath: String? = (voiceFile.local.isDownloadingCompleted && !voiceFile.local.path.isEmpty)
        ? voiceFile.local.path : nil
    return VoiceNoteVisual(
        voiceFileId: m.voiceNote.voice.id,
        duration: m.voiceNote.duration,
        mimeType: m.voiceNote.mimeType,
        waveform: m.voiceNote.waveform,
        caption: m.caption.text,
        localPath: localPath
    )
}

/// Builds an `AudioVisual` for `messageAudio` content, or returns `nil` for any
/// other content. Looks up the audio file id in `fileLocals` for the freshest
/// local-path snapshot, falling back to the message-embedded `File` when the
/// store hasn't seen `updateFile` yet. Display title falls back through
/// `fileName` to "Audio". Album art is the embedded minithumbnail (no download).
///
/// Internal (not private) so `AudioVisualTests` can exercise it directly.
/// Consider moving these tests behind `messageRows(...)` if direct access
/// becomes a maintenance burden.
func audioVisual(for content: MessageContent, fileLocals: [Int: File]) -> AudioVisual? {
    guard case .messageAudio(let m) = content else { return nil }
    let a = m.audio
    let audioFile = fileLocals[a.audio.id] ?? a.audio
    let localPath: String? = (audioFile.local.isDownloadingCompleted && !audioFile.local.path.isEmpty)
        ? audioFile.local.path : nil
    let displayTitle = a.title.isEmpty ? (a.fileName.isEmpty ? "Audio" : a.fileName) : a.title
    return AudioVisual(
        audioFileId: a.audio.id,
        duration: a.duration,
        title: displayTitle,
        performer: a.performer,
        albumArt: a.albumCoverMinithumbnail?.data,
        caption: m.caption.text,
        localPath: localPath
    )
}

/// Builds a `DocumentVisual` for `messageDocument` content, or nil otherwise. Looks up the
/// document file id in `fileLocals` for the freshest local-path/size snapshot, falling back to
/// the message-embedded `File`. Internal so `DocumentVisualTests` can exercise it directly.
func documentVisual(for content: MessageContent, fileLocals: [Int: File]) -> DocumentVisual? {
    guard case .messageDocument(let m) = content else { return nil }
    let d = m.document
    let docFile = fileLocals[d.document.id] ?? d.document
    let localPath: String? = (docFile.local.isDownloadingCompleted && !docFile.local.path.isEmpty)
        ? docFile.local.path : nil
    return DocumentVisual(
        documentFileId: d.document.id,
        fileName: d.fileName.isEmpty ? "File" : d.fileName,
        sizeBytes: docFile.size != 0 ? docFile.size : docFile.expectedSize,
        localPath: localPath,
        caption: m.caption.text
    )
}

/// Resolves the incoming-group sender label (name + palette index) for a message,
/// or `nil` when no label should be shown (outgoing, private chat, non-user sender,
/// or missing/empty cached name). Name and index are always produced together.
private func senderLabel(
    for msg: CachedMessage,
    chatType: ChatType,
    userNames: [Int64: String]
) -> (name: String, colorIndex: Int)? {
    if msg.isOutgoing { return nil }
    switch chatType {
    case .chatTypeBasicGroup, .chatTypeSupergroup:
        if case .messageSenderUser(let u) = msg.senderId,
           let name = userNames[u.userId],
           !name.isEmpty {
            return (name, paletteIndex(for: u.userId))
        }
        return nil
    default:
        return nil
    }
}
