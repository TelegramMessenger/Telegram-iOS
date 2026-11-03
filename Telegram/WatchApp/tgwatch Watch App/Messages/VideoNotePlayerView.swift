import SwiftUI
import UIKit
import AVKit
import AVFoundation
import OSLog

/// Full-screen sheet that plays a round video note inside a 180pt masked circle
/// with AVKit chrome suppressed. State machine mirrors `VideoPlayerView`:
/// preparing → playing → (replay) → dismiss. Chrome suppression uses two tricks
/// from `VideoPlayerView`: `.allowsHitTesting(false)` on the `VideoPlayer` so
/// taps never trigger chrome reveal, and `.opacity(0)` at end-of-playback so
/// AVKit's centered play arrow is hidden behind a peer preview image + Replay
/// button.
struct VideoNotePlayerView: View {
    let note: VideoNoteVisual

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .preparing(progress: 0)
    @State private var player: AVPlayer?
    @State private var hasReachedEnd = false
    @State private var endObserver: NSObjectProtocol?
    @State private var statusObserver: NSKeyValueObservation?

    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "videoplayer")

    enum Phase: Equatable {
        case preparing(progress: Double)
        case playing
        case failed(String)
    }

    private let diameter: CGFloat = 180

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .onAppear {
            if let path = note.videoLocalPath, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                setupPlayer(path: path)
                phase = .playing
            } else {
                store.requestFileDownload(fileId: note.videoFileId, priority: 2)
            }
        }
        .onChange(of: store.fileSnapshot(fileId: note.videoFileId)) { _, snap in
            guard let snap else { return }
            if snap.local.isDownloadingCompleted, !snap.local.path.isEmpty {
                if player == nil {
                    setupPlayer(path: snap.local.path)
                    phase = .playing
                }
            } else {
                let total = max(1, snap.expectedSize)
                let progress = Double(snap.local.downloadedSize) / Double(total)
                phase = .preparing(progress: min(1, max(0, progress)))
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
            statusObserver?.invalidate()
            statusObserver = nil
            try? AVAudioSession.sharedInstance().setActive(false)
            store.cancelFileDownload(fileId: note.videoFileId)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .preparing(let progress):
            ZStack {
                previewImage
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                VStack(spacing: 4) {
                    ProgressView()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        case .playing:
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                        .opacity(hasReachedEnd ? 0 : 1)
                }
                if hasReachedEnd {
                    previewImage
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                    Button {
                        player?.seek(to: .zero)
                        player?.play()
                        hasReachedEnd = false
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    phase = .preparing(progress: 0)
                    store.requestFileDownload(fileId: note.videoFileId, priority: 2)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let path = note.thumbLocalPath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFill().blur(radius: 4)
        } else if let data = note.minithumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill().blur(radius: 4)
        } else {
            Color.gray.opacity(0.3)
        }
    }

    private func setupPlayer(path: String) {
        let p = AVPlayer(url: URL(fileURLWithPath: path))
        if let item = p.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                hasReachedEnd = true
            }
            statusObserver = item.observe(\.status, options: [.new]) { item, _ in
                if item.status == .failed {
                    Task { @MainActor in
                        phase = .failed("Could not play video")
                    }
                }
            }
        }
        activatePlaybackSession()
        player = p
        p.play()
    }

    /// watchOS routes AVPlayer audio to the speaker only under an active `.playback`
    /// session; without it the video note plays silently. See VideoPlayerView.
    private func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            logger.error("audio session activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
