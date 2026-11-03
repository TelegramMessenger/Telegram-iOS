import UIKit

public final class WalletGiftStickerPlayback {
    public struct Frame {
        public let image: UIImage?
        public let grow: CGFloat
    }

    private struct Track {
        let media: WalletGiftStickerMedia
        let start: Double
        let enlarge: Bool
        var head: Double = 0
        var requested = false
        var image: UIImage?
        var ended: Double?
    }

    private final class Target: NSObject {
        weak var owner: WalletGiftStickerPlayback?
        @objc func tick() { self.owner?.tick() }
    }

    private var tracks: [String: Track] = [:]
    private var link: CADisplayLink?
    public var updated: (([String: Frame]) -> Void)?

    public init() {}

    deinit {
        self.link?.invalidate()
    }

    public var isEmpty: Bool { self.tracks.isEmpty }

    public func play(_ id: String, media: WalletGiftStickerMedia, enlarge: Bool) {
        guard media.first != nil else { return }
        self.tracks[id] = Track(media: media, start: CACurrentMediaTime(), enlarge: enlarge, image: media.first?.image)
        if self.link == nil {
            let target = Target()
            target.owner = self
            let link = CADisplayLink(target: target, selector: #selector(Target.tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        self.tick()
    }

    public func stop(_ id: String? = nil) {
        if let id {
            guard self.tracks.removeValue(forKey: id) != nil else { return }
        } else {
            guard !self.tracks.isEmpty else { return }
            self.tracks.removeAll()
        }
        self.tick()
    }

    private func tick() {
        let now = CACurrentMediaTime()
        var frames: [String: Frame] = [:]
        for (id, initial) in self.tracks {
            var track = initial
            let up: CGFloat
            if let ended = track.ended {
                guard track.enlarge, now - ended < 0.34 else {
                    self.tracks.removeValue(forKey: id)
                    continue
                }
                up = 1 - Self.ease((now - ended) / 0.34)
            } else {
                up = Self.ease((now - track.start) / 0.22)
                if !track.requested && now - track.start >= track.head {
                    let start = track.start, head = track.head, media = track.media
                    track.requested = media.frame(at: head) { [weak self] frame in
                        guard let self, var current = self.tracks[id], current.start == start else { return }
                        current.requested = false
                        if let frame { current.image = frame.image }
                        current.head = head + 1.0 / 30.0
                        if current.head >= media.duration || frame == nil { current.ended = CACurrentMediaTime() }
                        self.tracks[id] = current
                    }
                }
                self.tracks[id] = track
            }
            frames[id] = Frame(image: track.ended == nil ? track.image : track.media.first?.image,
                grow: track.enlarge ? 1 + 0.22 * up : 1)
        }
        self.updated?(frames)
        if self.tracks.isEmpty {
            self.link?.invalidate()
            self.link = nil
        }
    }

    private static func ease(_ value: Double) -> CGFloat {
        let t = CGFloat(max(0, min(1, value)))
        return t * t * (3 - 2 * t)
    }
}
