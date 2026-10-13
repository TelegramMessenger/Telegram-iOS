import SwiftUI
import AVFoundation
import ImageIO
import UserNotifications
import WatchKit

/// Long-look interface for the message notifications the iPhone app mirrors to the watch.
///
/// watchOS stacks a chat's notifications by `threadIdentifier`, but tapping the stack opens the
/// long look for one notification only (bugs.telegram.org/c/63110). This interface shows every
/// delivered notification of that thread instead, newest first, so the chat's recent history
/// scrolls with the Digital Crown.
///
/// The actions under it (Reply) come from the category the iPhone app registers, and the reply
/// is delivered to the iPhone app, which sends it.
///
/// Unlike the system interface it does not show the sender's photo: the iPhone app attaches it
/// to the message intent, which a notification does not expose.
final class MessageNotificationController: WKUserNotificationHostingController<MessageNotificationView> {
    /// `body` is read once, and this controller has no `setNeedsBodyUpdate()`, so later
    /// notifications reach the view through this observed model.
    private let model = MessageNotificationModel()
    private var latestEntryId: String?

    /// Interactive so a voice message's play button takes the tap. In this mode a tap on the
    /// content no longer opens the app by itself, so a tap on a message does it (`openChat`).
    override class var isInteractive: Bool { true }

    override init() {
        super.init()
        model.openChat = { [weak self] in
            // Opens the app with this notification; `TgwatchAppDelegate` opens its chat. All
            // the listed messages are in this notification's chat.
            self?.performNotificationDefaultAction()
        }
    }

    override var body: MessageNotificationView {
        MessageNotificationView(model: model)
    }

    override func didDeactivate() {
        super.didDeactivate()
        model.voice.stop()
    }

    /// With a custom interface the system asks this controller for the text responses of an
    /// input action (the iPhone app's Reply) before showing the input, and offers none of its
    /// own (`super` returns none). Without an answer it logs "got nil text suggestions" and
    /// never opens the input. The old watch app's reply presets, in the input's language.
    override func suggestionsForResponseToAction(withIdentifier identifier: String, for notification: UNNotification, inputLanguage: String) -> [String] {
        ReplyPresets.suggestions(forInputLanguage: inputLanguage)
    }

    /// Also called again while the long look is visible, when another notification of the
    /// thread arrives.
    override func didReceive(_ notification: UNNotification) {
        let received = MessageNotificationEntry(notification)
        let threadIdentifier = notification.request.content.threadIdentifier
        latestEntryId = received.id
        model.entries = MessageNotificationEntry.merging([received], into: model.entries)

        loadThumbnails(for: [notification])
        collectVoiceMessages(from: [notification])

        // Preview privacy is the system's: watchOS does not expose the preview setting to apps,
        // and with notification privacy on it shows only a summary until the user taps, before
        // this interface is created. The content drawn here is what the iPhone app's extension
        // delivered, which already applies the app lock and preview settings.
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
            let thread = delivered.filter { MessageNotificationEntry.isInThread(threadIdentifier, $0) }
            DispatchQueue.main.async {
                guard let self, self.latestEntryId == received.id else { return }
                self.model.entries = MessageNotificationEntry.merging(thread.map(MessageNotificationEntry.init) + [received], into: self.model.entries)
                self.loadThumbnails(for: thread)
                self.collectVoiceMessages(from: thread)
            }
        }
    }

    /// Voice messages reach the notification as an "audio" attachment, already converted to AAC
    /// by the iPhone app (`NotificationService.swift`), which `AVPlayer` plays as is.
    private func collectVoiceMessages(from notifications: [UNNotification]) {
        for notification in notifications {
            if let attachment = notification.request.content.attachments.first(where: { $0.identifier == "audio" }) {
                model.voiceMessages[notification.request.identifier] = attachment.url
            }
        }
    }

    /// Photos, video thumbnails and stickers reach the notification as an "image" attachment
    /// (`NotificationService.swift`). Decoded off the main thread, downscaled to the content width.
    private func loadThumbnails(for notifications: [UNNotification]) {
        let missing = notifications.filter { model.thumbnails[$0.request.identifier] == nil }
        guard !missing.isEmpty else { return }
        let maxPixelWidth = contentFrame.width * WKInterfaceDevice.current().screenScale
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var loaded: [String: UIImage] = [:]
            for notification in missing {
                if let image = MessageNotificationThumbnail.image(for: notification, maxPixelWidth: maxPixelWidth) {
                    loaded[notification.request.identifier] = image
                }
            }
            guard !loaded.isEmpty else { return }
            DispatchQueue.main.async {
                self?.model.thumbnails.merge(loaded) { current, _ in current }
            }
        }
    }
}

enum MessageNotificationThumbnail {
    static func image(for notification: UNNotification, maxPixelWidth: CGFloat) -> UIImage? {
        guard let attachment = notification.request.content.attachments.first(where: { $0.identifier == "image" }) else {
            return nil
        }
        // Attachment files of a delivered notification are only readable inside this scope.
        let url = attachment.url
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        // Decodes straight to the thumbnail size, so a full-size photo is never held in memory.
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelWidth, 1),
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}

@Observable @MainActor
final class MessageNotificationModel {
    var entries: [MessageNotificationEntry] = []
    /// By notification identifier; kept apart from the entries so they stay plain values.
    var thumbnails: [String: UIImage] = [:]
    /// The voice message attachment's file, by notification identifier.
    var voiceMessages: [String: URL] = [:]
    @ObservationIgnored let voice = MessageNotificationVoicePlayer()
    @ObservationIgnored var openChat: () -> Void = {}

    init(entries: [MessageNotificationEntry] = [], thumbnails: [String: UIImage] = [:]) {
        self.entries = entries
        self.thumbnails = thumbnails
    }
}

/// Plays one notification's voice message at a time through the app's `AVPlayerBackend`,
/// which also activates the playback audio session watchOS needs for sound.
@Observable @MainActor
final class MessageNotificationVoicePlayer {
    private(set) var playingId: String?
    private(set) var isPaused = false
    private(set) var elapsed: Double = 0
    private(set) var failedId: String?

    @ObservationIgnored private var backend: AVPlayerBackend?
    /// Attachment files are only readable inside their security scope, and `AVPlayer` reads
    /// while it plays, so the scope stays open until playback stops.
    @ObservationIgnored private var scopedURL: URL?

    func toggle(id: String, url: URL) {
        if playingId == id, let backend {
            if isPaused {
                backend.play()
            } else {
                backend.pause()
            }
            isPaused.toggle()
            return
        }
        stop()
        let isScoped = url.startAccessingSecurityScopedResource()
        scopedURL = isScoped ? url : nil
        let backend = AVPlayerBackend()
        backend.onProgress = { [weak self] seconds in
            self?.elapsed = seconds
        }
        backend.onEnded = { [weak self] in
            self?.stop()
        }
        backend.onFailed = { [weak self] _ in
            self?.stop()
            self?.failedId = id
        }
        do {
            try backend.load(url: url)
            backend.play()
            self.backend = backend
            playingId = id
            failedId = nil
        } catch {
            stop()
            failedId = id
        }
    }

    func stop() {
        backend?.stop()
        backend = nil
        playingId = nil
        isPaused = false
        elapsed = 0
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }
}

/// The categories the iPhone app registers for chat notifications (`AppDelegate.swift`):
/// private messages (`r`, `m`), group messages (`gr`, `gm`), channel posts (`c`) and
/// reactions (`t`). The notification service extension assigns them per message.
enum MessageNotificationCategory {
    static let privateMessage = "r"
    static let privateMediaMessage = "m"
    static let groupMessage = "gr"
    static let groupMediaMessage = "gm"
    static let channelMessage = "c"
    static let reaction = "t"
}

struct MessageNotificationEntry: Identifiable, Equatable {
    /// At most this many of a thread's notifications are shown; the oldest are dropped. The
    /// system puts the actions (Reply) after the content, so a longer list pushes them away.
    static let maxCount = 10

    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let body: String

    init(id: String, date: Date, title: String, subtitle: String, body: String) {
        self.id = id
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }

    /// When the phone hides previews (passcode lock), the extension has already put the
    /// placeholder in `body`, so it is shown as delivered.
    init(_ notification: UNNotification) {
        let content = notification.request.content
        self.init(
            id: notification.request.identifier,
            date: notification.date,
            title: content.title,
            subtitle: content.subtitle,
            body: content.body
        )
    }

    /// Whether a delivered notification belongs to the thread. A notification without a thread
    /// is shown alone.
    static func isInThread(_ threadIdentifier: String, _ notification: UNNotification) -> Bool {
        !threadIdentifier.isEmpty && notification.request.content.threadIdentifier == threadIdentifier
    }

    /// Unique by id, oldest first, capped to the newest `maxCount`.
    static func merging(_ new: [MessageNotificationEntry], into existing: [MessageNotificationEntry]) -> [MessageNotificationEntry] {
        var byId: [String: MessageNotificationEntry] = [:]
        for entry in existing + new {
            byId[entry.id] = entry
        }
        let sorted = byId.values.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
        }
        return Array(sorted.suffix(maxCount))
    }
}

struct MessageNotificationView: View {
    /// Points a touch may move and still count as a tap on a message.
    static let tapSlop: CGFloat = 8

    let model: MessageNotificationModel

    var body: some View {
        // Newest first, so the message that was tapped is on screen and the crown scrolls back
        // through the chat. The long look scrolls its whole content, so this is a plain stack
        // rather than a nested scroll view.
        let newestFirst = Array(model.entries.reversed())
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(newestFirst.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                }
                MessageNotificationEntryView(
                    entry: entry,
                    thumbnail: model.thumbnails[entry.id],
                    voiceMessage: model.voiceMessages[entry.id],
                    voice: model.voice,
                    showsTitle: index == 0 || newestFirst[index - 1].title != entry.title,
                    openChat: model.openChat
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("messageNotification")
    }
}

private struct MessageNotificationEntryView: View {
    let entry: MessageNotificationEntry
    let thumbnail: UIImage?
    let voiceMessage: URL?
    let voice: MessageNotificationVoicePlayer
    /// The title (the chat, or the sender of a private chat) is shown when it changes, not on
    /// every message of a run.
    let showsTitle: Bool
    let openChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            message
                .contentShape(Rectangle())
                // Simultaneous, and only a touch that barely moved: the drag that scrolls the
                // notification must stay with the system (a tap gesture or button here took it).
                // Not on the voice button, whose tap plays.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        if hypot(value.translation.width, value.translation.height) < MessageNotificationView.tapSlop {
                            openChat()
                        }
                    }
                )
            if let voiceMessage {
                MessageNotificationVoiceButton(id: entry.id, url: voiceMessage, voice: voice)
            }
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsTitle, !entry.title.isEmpty {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
            }
            if !entry.subtitle.isEmpty {
                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 120, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.body)
                    // Without this a message can stay cut to one line when more of the thread
                    // arrives after the first layout.
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MessageNotificationVoiceButton: View {
    let id: String
    let url: URL
    let voice: MessageNotificationVoicePlayer

    var body: some View {
        let isActive = voice.playingId == id
        let isPlaying = isActive && !voice.isPaused
        Button {
            voice.toggle(id: id, url: url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: voice.failedId == id ? "exclamationmark.circle" : (isPlaying ? "pause.fill" : "play.fill"))
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                if isActive {
                    Text(Duration.seconds(Int(voice.elapsed)), format: .time(pattern: .minuteSecond))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("messageNotification.voice")
    }
}

#if DEBUG
private let previewDate = Date(timeIntervalSince1970: 1_791_880_000)

#Preview("Private chat, three messages") {
    MessageNotificationView(model: MessageNotificationModel(entries: [
            MessageNotificationEntry(id: "a", date: previewDate, title: "Alice", subtitle: "", body: "Are you free tonight?"),
            MessageNotificationEntry(id: "b", date: previewDate + 120, title: "Alice", subtitle: "", body: "Dinner at 8?"),
            MessageNotificationEntry(id: "c", date: previewDate + 300, title: "Alice", subtitle: "", body: "I booked a table"),
        ])
    )
}

#Preview("Group, two senders") {
    MessageNotificationView(model: MessageNotificationModel(entries: [
            MessageNotificationEntry(id: "1", date: previewDate, title: "Weekend Trip", subtitle: "Bob", body: "Cabin is booked"),
            MessageNotificationEntry(id: "2", date: previewDate + 60, title: "Weekend Trip", subtitle: "Carol", body: "Great, I will bring snacks"),
        ])
    )
}
#endif
