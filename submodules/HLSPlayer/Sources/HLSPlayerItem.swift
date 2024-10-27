import Foundation
import TelegramCore

public final class HLSPlayerItem: NSObject {

    public var preferredPeakBitRate = 0.0
    public var presentationSize: CGSize = .zero

    var rate: Float = 0.0

    private(set) var streams: [Int: HLSPlayerStreamEntity] = [:]
    private(set) var baseURL: String

    private let masterURL: URL
    private let queue: DispatchQueue

    public init(url: URL) {
        baseURL = url.deletingLastPathComponent().absoluteString
        masterURL = url
        queue = DispatchQueue(
            label: "HLSPlayerItemQueue",
            qos: .userInitiated,
            attributes: .concurrent)
    }

    public func fetch(completion: @escaping () -> Void) {
        queue.async { [weak self] in
            self?.configure(completion: completion)
        }
    }
}

// MARK: - Private Configuration

private extension HLSPlayerItem {

    func configure(completion: @escaping () -> Void) {
        guard let masterPlaylistData = try? Data(contentsOf: masterURL),
              let masterPlaylistString = String(data: masterPlaylistData, encoding: .utf8) else {
            Logger.shared.log("HLSPlayer", "Error receiving master playlist data")
            return
        }

        handler(masterPlaylist: masterPlaylistString, completion: completion)
    }

    func handler(masterPlaylist: String, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        let masterPlaylistLines = masterPlaylist.components(separatedBy: "\n")
        masterPlaylistLines.forEach { line in
            autoreleasepool {
                if line.hasPrefix("#EXT-X-STREAM-INF:") {
                    group.enter()

                    let parts = line.components(separatedBy: ":")
                    let attributes = parts.last?.components(separatedBy: ",") ?? []

                    var bandWidth: Double?
                    var resolution: CGSize?
                    var codecs: String?
                    var frameRate: Double?

                    attributes.forEach { attribute in
                        autoreleasepool {
                            let keyValue = attribute.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "=")
                            let key = keyValue.first ?? ""
                            let value = keyValue.last ?? ""

                            switch key {
                            case "BANDWIDTH":
                                bandWidth = Double(value)
                            case "RESOLUTION":
                                let resolutionValues = value.components(separatedBy: "x")
                                if let width = Int(resolutionValues.first ?? ""),
                                   let height = Int(resolutionValues.last ?? "") {
                                    resolution = CGSize(width: width, height: height)
                                }
                            case "CODECS":
                                codecs = value
                            case "FRAME-RATE":
                                frameRate = Double(value)
                            default:
                                Logger.shared.log("HLSPlayer", "#EXT-X-STREAM-INF:\(key) key is not supported")
                            }
                        }
                    }

                    guard let index = masterPlaylistLines.firstIndex(of: line),
                          masterPlaylistLines.count > index + 1,
                          let mediaPlaylistURL = URL(string: "\(baseURL)\("\(masterPlaylistLines[index + 1])")"),
                          let mediaPlaylistData = try? Data(contentsOf: mediaPlaylistURL),
                          let mediaPlaylist = String(data: mediaPlaylistData, encoding: .utf8) else {
                        Logger.shared.log("HLSPlayer", "Error receiving playlist data")
                        group.leave()
                        return
                    }

                    handler(mediaPlaylist: mediaPlaylist, bandWidth: bandWidth, resolution: resolution, codecs: codecs, frameRate: frameRate)
                    group.leave()
                }
            }
        }

        group.wait()
        DispatchQueue.main.async {
            completion()
        }
    }

    func handler(mediaPlaylist: String, bandWidth: Double?, resolution: CGSize?, codecs: String?, frameRate: Double?) {
        var duration: Double?
        var sequence: Int?
        var segments: [HLSPlayerPlaylistEntity.Segment] = []

        let mediaPlaylistLines = mediaPlaylist.components(separatedBy: "\n")
        mediaPlaylistLines.forEach { line in
            autoreleasepool {
                if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                    if let targetDurationString = line.components(separatedBy: ":").last,
                       let targetDuration = Double(targetDurationString) {
                        duration = targetDuration
                    }
                } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
                    if let mediaSequenceString = line.components(separatedBy: ":").last,
                       let mediaSequence = Int(mediaSequenceString) {
                        sequence = mediaSequence
                    }
                } else if line.hasPrefix("#EXT-X-INDEPENDENT-SEGMENTS") {
                    // TODO: Add segment dependency processing
                } else if line.hasPrefix("#EXT-X-MAP:") {
                    if let parts = line.components(separatedBy: ":").last?.replacingOccurrences(of: "\"", with: "").components(separatedBy: ",") {
                        var uri: String?
                        var byteRange: HLSPlayerPlaylistEntity.ByteRange?
                        parts.forEach { part in
                            autoreleasepool {
                                let keyValue = part.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "=")
                                let key = keyValue.first ?? ""
                                let value = keyValue.last ?? ""
                                switch key {
                                case "URI":
                                    uri = value
                                case "BYTERANGE":
                                    let byteRangeParts = value.components(separatedBy: "@")
                                    if let length = Int(byteRangeParts.first ?? ""),
                                       let offset = Int(byteRangeParts.last ?? "") {
                                        byteRange = HLSPlayerPlaylistEntity.ByteRange(length: length, offset: offset)
                                    }
                                default:
                                    Logger.shared.log("HLSPlayer", "#EXT-X-MAP:\(key) key is not supported")
                                }
                            }
                        }
                        if let duration = duration,
                           let byteRange = byteRange,
                           let uri = uri {
                            let playlistMap = HLSPlayerPlaylistEntity.Segment(duration: duration, byteRange: byteRange, uri: uri)
                            segments.append(playlistMap)
                        }
                    }
                } else if line.hasPrefix("#EXTINF:") {
                    if let durationString = line.components(separatedBy: ":").last,
                       let duration = Double(durationString),
                       let index = mediaPlaylistLines.firstIndex(of: line),
                       mediaPlaylistLines.count > index + 2,
                       let byteRange = mediaPlaylistLines[index + 1].components(separatedBy: ":").last {
                        let uri = mediaPlaylistLines[index + 2]
                        let byteRangeParts = byteRange.components(separatedBy: "@")
                        if let length = Int(byteRangeParts.first ?? ""),
                           let offset = Int(byteRangeParts.last ?? "") {
                            let byteRange = HLSPlayerPlaylistEntity.ByteRange(length: length, offset: offset)
                            let playlist = HLSPlayerPlaylistEntity.Segment(duration: duration, byteRange: byteRange, uri: uri)
                            segments.append(playlist)
                        }
                    }
                }
            }
        }

        if let duration = duration, let sequence = sequence {
            let playlist = HLSPlayerPlaylistEntity(duration: duration, sequence: sequence, segments: segments)
            if let bandWidth = bandWidth, let resolution = resolution {
                let stream = HLSPlayerStreamEntity(bandWidth: bandWidth, resolution: resolution, codecs: codecs, frameRate: frameRate, playlist: playlist)
                streams[Int(bandWidth)] = stream
            } else {
                Logger.shared.log("HLSPlayer", "Error create stream")
            }
        } else {
            Logger.shared.log("HLSPlayer", "Error create playlist")
        }
    }
}
