import SwiftUI
import AVKit
import AVFoundation
import Combine
import OSLog
import UIKit
import TDShim  // for `File?` in handleSnapshot — note this shadows Swift.Error and Foundation.Date; we use neither here

/// Full-screen sheet content for downloading + playing a video.
///
/// State machine: `.preparing(progress:)` → `.playing` → optional Replay overlay when
/// playback ends. `.failed(...)` is reached only when the AVPlayer item transitions to
/// `.failed` (observed via `currentItem.publisher(for: \.status)`). Download-RPC errors
/// are swallowed by the store and never surface here; download stalls (no error, just
/// no progress) stay in `.preparing` indefinitely — the user dismisses to retry.
///
/// On appear, fires `requestFileDownload(fileId:priority:2)` (priority 2 jumps ahead of
/// off-screen bubble previews). On disappear, pauses the player, nils it (releasing the
/// audio session + decoder), cancels the status subscription, and fires
/// `cancelFileDownload(fileId:)` — TDLib short-circuits if the file already completed.
struct VideoPlayerView: View {
    let video: VideoVisual

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .preparing(progress: 0)
    @State private var player: AVPlayer?
    @State private var hasReachedEnd = false
    @State private var endObserver: NSObjectProtocol?
    @State private var statusObserver: AnyCancellable?

    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "videoplayer")

    enum Phase: Equatable {
        case preparing(progress: Double)   // 0...1
        case playing
        /// Reached only when AVPlayer's `currentItem.status` transitions to `.failed`.
        /// Download-RPC errors do NOT reach here (the store swallows them); download
        /// stalls also stay in `.preparing` until the user dismisses.
        case failed(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .onAppear { onAppear() }
        .onDisappear { onDisappear() }
        .onChange(of: store.fileSnapshot(fileId: video.videoFileId)) { _, snap in
            handleSnapshot(snap)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .preparing(let progress):
            preparingContent(progress: progress)
        case .playing:
            playingContent
        case .failed(let message):
            failedContent(message: message)
        }
    }

    // MARK: - Phase contents

    private func preparingContent(progress: Double) -> some View {
        ZStack {
            previewBackground.blur(radius: 6)
            VStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
        }
    }

    private var playingContent: some View {
        ZStack {
            if let player {
                // Hide AVKit's chrome (which centers its own play arrow at end-of-playback)
                // when our Replay overlay is showing — otherwise the two icons stack at the
                // same coordinates and the user can't tell which is which (or whose tap wins).
                VideoPlayer(player: player)
                    .opacity(hasReachedEnd ? 0 : 1)
                    .allowsHitTesting(!hasReachedEnd)
            }
            if hasReachedEnd {
                // Visual fallback so the screen isn't pure black under just the Replay icon.
                previewBackground.blur(radius: 6)
                Button {
                    player?.seek(to: .zero)
                    player?.play()
                    hasReachedEnd = false
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func failedContent(message: String) -> some View {
        ZStack {
            previewBackground.blur(radius: 6)
            VStack(spacing: 6) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    phase = .preparing(progress: 0)
                    store.requestFileDownload(fileId: video.videoFileId, priority: 2)
                    // If the file is already complete on disk, no further updateFile
                    // will arrive — short-circuit by re-handling the current snapshot
                    // so setupPlayer fires immediately.
                    handleSnapshot(store.fileSnapshot(fileId: video.videoFileId))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        if let path = video.preview.previewLocalPath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFit()
        } else if let data = video.preview.minithumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFit()
        } else {
            Color.gray.opacity(0.3)
        }
    }

    // MARK: - Lifecycle handlers

    private func onAppear() {
        if let path = video.videoLocalPath, FileManager.default.fileExists(atPath: path) {
            setupPlayer(path: path)
            return
        }
        // Initial snapshot in case updateFile already arrived before the view did.
        if let snap = store.fileSnapshot(fileId: video.videoFileId) {
            handleSnapshot(snap)
        }
        store.requestFileDownload(fileId: video.videoFileId, priority: 2)
    }

    private func onDisappear() {
        player?.pause()
        player = nil
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        statusObserver?.cancel()
        statusObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        store.cancelFileDownload(fileId: video.videoFileId)
    }

    /// watchOS routes AVPlayer audio to the speaker only under an active `.playback`
    /// session. Without this the video renders but is silent — the voice-note path is
    /// audible only because `AVAudioEngine.start()` activates the session implicitly.
    private func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            logger.error("audio session activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleSnapshot(_ snap: File?) {
        guard let snap else { return }
        if snap.local.isDownloadingCompleted, !snap.local.path.isEmpty {
            // Already in .playing? Don't reinit.
            if case .playing = phase { return }
            setupPlayer(path: snap.local.path)
            return
        }
        let denom = max(1, snap.expectedSize)
        let progress = Double(snap.local.downloadedSize) / Double(denom)
        phase = .preparing(progress: min(max(progress, 0), 1))
    }

    private func setupPlayer(path: String) {
        let url = URL(fileURLWithPath: path)
        let p = AVPlayer(url: url)
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            hasReachedEnd = true
        }
        statusObserver?.cancel()
        statusObserver = p.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                if status == .failed {
                    phase = .failed("Could not play video")
                } else if status == .readyToPlay {
                    let audioTracks = p.currentItem?.tracks.filter { $0.assetTrack?.mediaType == .audio } ?? []
                    logger.info("ready: audioTracks=\(audioTracks.count, privacy: .public) sessionCategory=\(AVAudioSession.sharedInstance().category.rawValue, privacy: .public)")
                }
            }
        activatePlaybackSession()
        player = p
        phase = .playing
        p.play()
        logger.info("playback started fileId=\(video.videoFileId, privacy: .public)")
    }
}
