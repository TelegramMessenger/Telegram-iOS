import SwiftUI
import UIKit
import WatchKit
import RLottieKit

/// Renders one TGS sticker. Plays once when the view first becomes visible, freezes on
/// the last frame, and replays on tap. Drops the `LottieAnimation` (and its rlottie
/// backing buffers) on disappear so off-screen stickers cost nothing.
///
/// Pre-download / pre-load fallback chain: while the TGS hasn't been loaded yet, render
/// the sticker's raster thumbnail if available, otherwise a gray placeholder.
struct LottieAnimationView: View {
    let sticker: StickerVisual
    let displaySize: CGSize

    enum PlayState: Equatable {
        case idle
        case playing(start: Foundation.Date)
        case finished
        case failed
    }

    @State private var animation: LottieAnimation? = nil
    @State private var playState: PlayState = .idle
    @State private var renderedFrame: CGImage? = nil

    private var screenScale: CGFloat { WKInterfaceDevice.current().screenScale }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            ZStack {
                placeholderLayer
                if let frame = renderedFrame {
                    Image(decorative: frame, scale: screenScale)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: displaySize.width, height: displaySize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if case .finished = playState, animation != nil {
                    playState = .playing(start: Foundation.Date())
                }
            }
            .onAppear { startIfReady() }
            .onChange(of: sticker.localPath) { _, _ in startIfReady() }
            .onDisappear { teardown() }
            .onChange(of: ctx.date) { _, now in tick(now: now) }
        }
    }

    @ViewBuilder
    private var placeholderLayer: some View {
        if renderedFrame == nil {
            if let thumbPath = sticker.thumbnailLocalPath,
               let img = UIImage(contentsOfFile: thumbPath) {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Color.gray.opacity(0.2)
            }
        }
    }

    private func startIfReady() {
        guard animation == nil, let path = sticker.localPath else { return }
        let url = URL(fileURLWithPath: path)
        if let anim = LottieAnimation(tgsFileURL: url) {
            animation = anim
            playState = .playing(start: Foundation.Date())
        } else {
            playState = .failed
        }
    }

    private func teardown() {
        animation = nil
        renderedFrame = nil
        playState = .idle
    }

    private func tick(now: Foundation.Date) {
        guard let animation, case .playing(let start) = playState else { return }
        let elapsed = now.timeIntervalSince(start)
        let duration = animation.duration
        if elapsed >= duration {
            let last = animation.renderFrame(
                index: animation.frameCount - 1,
                size: displaySize,
                scale: screenScale
            )
            renderedFrame = last
            playState = .finished
            return
        }
        let frameIndex = min(animation.frameCount - 1, Int(elapsed * Double(animation.frameRate)))
        renderedFrame = animation.renderFrame(
            index: frameIndex,
            size: displaySize,
            scale: screenScale
        )
    }
}
