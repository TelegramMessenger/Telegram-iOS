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
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    override func willActivate() {
        super.willActivate()
        startRefreshing()
    }

    /// Messages deleted or read elsewhere while the long look is open: the iPhone app removes
    /// their notifications, so the list is re-read and drops those no longer delivered.
    static let refreshInterval: TimeInterval = 3
    private var refreshTimer: Timer?
    private var threadIdentifier = ""
    private var recipientUserId: Int64?

    private func startRefreshing() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            guard let thread = self?.threadIdentifier else { return }
            let recipient = self?.recipientUserId
            UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
                let ids = Set(delivered.filter { MessageNotificationEntry.isInThread(thread, recipient: recipient, $0) }.map(\.request.identifier))
                // Nothing of the thread listed: the system may not list mirrored notifications to
                // the app at all, so that is no reason to clear the list.
                guard !ids.isEmpty else { return }
                DispatchQueue.main.async {
                    guard let self else { return }
                    let latest = self.latestEntryId
                    let kept = self.model.entries.filter { ids.contains($0.id) || $0.id == latest }
                    if kept.count != self.model.entries.count {
                        self.model.entries = kept
                    }
                }
            }
        }
    }

    /// With a custom interface the system asks this controller for the text responses of an
    /// input action (the iPhone app's Reply) before showing the input, and offers none of its
    /// own (`super` returns none). Without an answer it logs "got nil text suggestions" and
    /// never opens the input. The old watch app's reply presets, in the app's language.
    override func suggestionsForResponseToAction(withIdentifier identifier: String, for notification: UNNotification, inputLanguage: String) -> [String] {
        ReplyPresets.suggestions()
    }

    /// Also called again while the long look is visible, when another notification of the
    /// thread arrives.
    ///
    /// The thread and its thumbnails are gathered before this returns: the system sizes the long
    /// look, and places the actions (Reply) under it, from the content drawn first, and content
    /// that grows later cannot be scrolled to the end (Reply became unreachable).
    override func didReceive(_ notification: UNNotification) {
        let received = MessageNotificationEntry(notification)
        let threadIdentifier = notification.request.content.threadIdentifier
        let userInfo = notification.request.content.userInfo
        let recipient = NotificationChatRouter.recipientUserId(fromUserInfo: userInfo)
        self.threadIdentifier = threadIdentifier
        self.recipientUserId = recipient
        latestEntryId = received.id

        // Another account of the iPhone app (or none named): the app cannot reply as that account
        // or open its chats, so Reply is removed and a tap does not open the chat. While the app
        // does not know its own account yet, both stay; sending and opening check again.
        let isActiveAccount = NotificationChatRouter.isForActiveAccount(userInfo)
        model.opensChat = isActiveAccount != false
        if isActiveAccount == false {
            notificationActions = notificationActions.filter { $0.identifier != "reply" }
        }

        // Preview privacy is the system's: watchOS does not expose the preview setting to apps,
        // and with notification privacy on it shows only a summary until the user taps, before
        // this interface is created. The content drawn here is what the iPhone app's extension
        // delivered, which already applies the app lock and preview settings.
        if let delivered = Self.deliveredNotifications(timeout: Self.deliveredWaitTimeout) {
            let thread = delivered.filter { MessageNotificationEntry.isInThread(threadIdentifier, recipient: recipient, $0) } + [notification]
            show(thread, latest: received)
            return
        }
        // The system did not answer in time: show this notification, add the thread when it does.
        show([notification], latest: received)
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
            let thread = delivered.filter { MessageNotificationEntry.isInThread(threadIdentifier, recipient: recipient, $0) }
            DispatchQueue.main.async {
                guard let self, self.latestEntryId == received.id else { return }
                self.show(thread, latest: received)
            }
        }
    }

    /// Long enough for the system to list the delivered notifications, short enough not to
    /// delay the long look noticeably if it does not.
    static let deliveredWaitTimeout: TimeInterval = 1

    /// The delivered notifications, or nil if the system did not answer within `timeout`. The
    /// completion runs on a queue of the notification center, not the main queue.
    private static func deliveredNotifications(timeout: TimeInterval) -> [UNNotification]? {
        let semaphore = DispatchSemaphore(value: 0)
        let result = Atomic<[UNNotification]?>(nil)
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            result.value = delivered
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else { return nil }
        return result.value
    }

    private func show(_ notifications: [UNNotification], latest: MessageNotificationEntry) {
        model.entries = MessageNotificationEntry.merging(notifications.map(MessageNotificationEntry.init) + [latest], into: model.entries)
        let shown = Set(model.entries.map(\.id))
        let listed = notifications.filter { shown.contains($0.request.identifier) }
        loadThumbnails(for: listed)
        collectVoiceMessages(from: listed)
    }

    /// Voice messages reach the notification as an "audio" attachment, already converted to AAC
    /// by the iPhone app (`NotificationService.swift`), which `AVPlayer` plays as is.
    private func collectVoiceMessages(from notifications: [UNNotification]) {
        for notification in notifications {
            let id = notification.request.identifier
            if model.voiceMessages[id] == nil, let attachment = notification.request.content.attachments.first(where: { $0.identifier == "audio" }) {
                model.voiceMessages[id] = attachment.url
                let info = MessageNotificationVoicePlayer.info(of: attachment.url)
                model.voiceDurations[id] = info?.duration
                model.voiceWaveforms[id] = info?.waveform
            }
        }
    }

    /// Photos, video thumbnails and stickers reach the notification as an "image" attachment
    /// (`NotificationService.swift`). Decoded here, before the long look is first drawn (see
    /// `didReceive`), straight to the content width: at most `maxCount` small thumbnails.
    private func loadThumbnails(for notifications: [UNNotification]) {
        // `contentFrame` can still be empty here, before the first layout.
        let maxPixelWidth = WKInterfaceDevice.current().screenBounds.width * WKInterfaceDevice.current().screenScale
        for notification in notifications where model.thumbnails[notification.request.identifier] == nil {
            if let image = MessageNotificationThumbnail.image(for: notification, maxPixelWidth: maxPixelWidth) {
                model.thumbnails[notification.request.identifier] = image
            }
        }
    }
}

/// A value written on one queue and read on another after a semaphore.
private final class Atomic<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
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
    /// Their length in seconds and waveform, read when they are listed.
    var voiceDurations: [String: Double] = [:]
    var voiceWaveforms: [String: [Float]] = [:]
    @ObservationIgnored let voice = MessageNotificationVoicePlayer()
    @ObservationIgnored var openChat: () -> Void = {}
    /// False for another account's notification (see `NotificationChatRouter.isForActiveAccount`).
    @ObservationIgnored var opensChat = true

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

    nonisolated static let waveformSamples = 32

    /// The length and waveform of an audio file, nil if it cannot be read. A notification has
    /// no waveform of its own (a chat message carries one), so it is computed: the peak level
    /// of each of `waveformSamples` slices, scaled to the loudest.
    nonisolated static func info(of url: URL) -> (duration: Double, waveform: [Float])? {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let file = try? AVAudioFile(forReading: url),
              file.length > 0,
              file.processingFormat.sampleRate > 0 else {
            return nil
        }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        // Read in chunks so a long voice message is never decoded into memory whole: the
        // notification interface runs with a small memory limit.
        let chunkFrames: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkFrames) else {
            return (duration, [])
        }
        let totalFrames = Int(file.length)
        let sliceLength = max(1, totalFrames / waveformSamples)
        var peaks = [Float](repeating: 0, count: waveformSamples)
        var position = 0
        while position < totalFrames {
            buffer.frameLength = 0
            guard (try? file.read(into: buffer, frameCount: chunkFrames)) != nil,
                  buffer.frameLength > 0,
                  let channel = buffer.floatChannelData?[0] else {
                break
            }
            for frame in 0..<Int(buffer.frameLength) {
                let slice = min(waveformSamples - 1, (position + frame) / sliceLength)
                peaks[slice] = max(peaks[slice], abs(channel[frame]))
            }
            position += Int(buffer.frameLength)
        }
        let loudest = peaks.max() ?? 0
        return (duration, loudest > 0 ? peaks.map { $0 / loudest } : [])
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
    /// Two accounts can have a chat with the same peer, and so the same thread identifier: only
    /// the notifications received on the same account are listed together.
    static func isInThread(_ threadIdentifier: String, recipient: Int64?, _ notification: UNNotification) -> Bool {
        let content = notification.request.content
        return !threadIdentifier.isEmpty
            && content.threadIdentifier == threadIdentifier
            && NotificationChatRouter.recipientUserId(fromUserInfo: content.userInfo) == recipient
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
                    voiceDuration: model.voiceDurations[entry.id],
                    voiceWaveform: model.voiceWaveforms[entry.id] ?? [],
                    voice: model.voice,
                    showsTitle: index == 0 || newestFirst[index - 1].title != entry.title,
                    openChat: model.opensChat ? model.openChat : {}
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
    let voiceDuration: Double?
    let voiceWaveform: [Float]
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
                MessageNotificationVoiceButton(id: entry.id, url: voiceMessage, duration: voiceDuration, waveform: voiceWaveform, voice: voice)
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
                MessageNotificationThumbnailView(image: thumbnail)
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

/// A thumbnail with a height fixed from its aspect ratio: the system measures the long look's
/// content to size it (and place Reply after it), and an image sized only at layout time
/// measured short, so the list could not be scrolled to its end.
private struct MessageNotificationThumbnailView: View {
    static let maxHeight: CGFloat = 120

    let image: UIImage

    var body: some View {
        let width = WKInterfaceDevice.current().screenBounds.width
        let aspect = image.size.width > 0 ? image.size.height / image.size.width : 1
        let height = min(Self.maxHeight, (width * aspect).rounded())
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A full-width bar: play/pause, the waveform (as in chats) filled as it plays, and the length
/// (the position while playing).
private struct MessageNotificationVoiceButton: View {
    static let height: CGFloat = 36

    let id: String
    let url: URL
    let duration: Double?
    let waveform: [Float]
    let voice: MessageNotificationVoicePlayer

    var body: some View {
        let isActive = voice.playingId == id
        let isPlaying = isActive && !voice.isPaused
        let failed = voice.failedId == id
        let progress = isActive && (duration ?? 0) > 0 ? min(1, voice.elapsed / (duration ?? 1)) : 0
        let shownSeconds = isActive ? voice.elapsed : (duration ?? 0)
        Button {
            voice.toggle(id: id, url: url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: failed ? "exclamationmark.circle.fill" : (isPlaying ? "pause.circle.fill" : "play.circle.fill"))
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                WaveformBarsView(amplitudes: waveform, progress: progress, isOutgoing: false)
                if isActive || duration != nil {
                    Text(Duration.seconds(Int(shownSeconds.rounded(.down))), format: .time(pattern: .minuteSecond))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Message.Audio"))
        .accessibilityValue(Text(Duration.seconds(Int(shownSeconds.rounded(.down))), format: .time(pattern: .minuteSecond)))
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
