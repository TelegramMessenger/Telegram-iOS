import AVFoundation
import TelegramCore

public final class HLSPlayer: NSObject {

    protocol LayerDelegate  {
        func play()
        func pause()
        func stop()
        func rendering(at: CMSampleBuffer) -> Bool
    }

    public enum ActionAtItemEnd {
        case pause
        case replay
    }

    public var volume: Double {
        get {
            audioOutput.volume
        }
        set {
            audioOutput.volume(at: newValue)
        }
    }

    public var rate: Float {
        get {
            currentItem?.rate ?? 0.0
        }
        set {
            currentItem?.rate = newValue
        }
    }

    public var actionAtItemEnd: ActionAtItemEnd = .pause

    var layerDelegate: LayerDelegate?

    public private(set) var currentItem: HLSPlayerItem?

    private let queue: DispatchQueue
    private let queueAudio: DispatchQueue
    private let queueVideo: DispatchQueue
    private let fileManager: FileManager
    private var tempFileURL: URL?
    private var reader: AVAssetReader?
    private var audioOutput: HLSPlayerAudioOutput
    private var videoOutput: HLSPlayerVideoOutput

    private var currentSegmentNumber = -1
    private var currenTimeSeconds = 0.0
    private var currentBandwidth = 0.0
    private var mastersData: [Int: Data] = [:]

    public override init() {
        queue = DispatchQueue(
            label: "HLSPlayerQueue",
            qos: .userInitiated,
            attributes: .concurrent)
        queueAudio = DispatchQueue(
            label: "HLSPlayerAudioQueue",
            qos: .userInitiated)
        queueVideo = DispatchQueue(
            label: "HLSPlayerVideoQueue",
            qos: .userInitiated)
        fileManager = FileManager.default
        audioOutput = HLSPlayerAudioOutput()
        videoOutput = HLSPlayerVideoOutput()
    }

    deinit {
        if let url = tempFileURL {
            try? fileManager.removeItem(at: url)
        }
    }

    public func play() {
        DispatchQueue.main.async {
            self.audioOutput.play()
            self.layerDelegate?.play()
        }
    }

    public func pause() {
        DispatchQueue.main.async {
            self.audioOutput.pause()
            self.layerDelegate?.pause()
        }
    }

    public func stiop() {
        DispatchQueue.main.async {
            self.audioOutput.stop()
            self.layerDelegate?.stop()
        }
    }

    public func replaceCurrent(item: HLSPlayerItem?) {
        self.currentItem = item
        if item != nil {
            currentItem?.fetch { [weak self] in
                self?.loadSegment()
            }
        }
    }

    public func seek(to: CMTime) {

    }

    public func currentTime() -> CMTime {
        CMTime(seconds: currenTimeSeconds, preferredTimescale: 30)
    }
}

// MARK: - Private

private extension HLSPlayer {

    func loadSegment() {
        guard let item = currentItem else {
            Logger.shared.log("HLSPlayer", "Error item for load segment")
            return
        }
        let bitRate = currentBitRate(at: item)
        guard let stream = item.streams[bitRate] else {
            Logger.shared.log("HLSPlayer", "Error item for load segment")
            return
        }

        if currentSegmentNumber < 0 {
            currentSegmentNumber = stream.playlist.sequence
        }

        let segmentNumber = mastersData[bitRate] == nil ? 0 : currentSegmentNumber
        let isEndItem = (segmentNumber + 1) == stream.playlist.segments.count
        guard segmentNumber < stream.playlist.segments.count else {
            Logger.shared.log("HLSPlayer", "Error the number exceeds of segments")
            return
        }

        let segment = stream.playlist.segments[segmentNumber]
        guard let segmentURL = URL(string: "\(item.baseURL)\(segment.uri)") else {
            Logger.shared.log("HLSPlayer", "Error segment URL")
            return
        }

        var request = URLRequest(url: segmentURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("bytes=\(segment.byteRange.offset)-\(segment.byteRange.offset + segment.byteRange.length - 1)", forHTTPHeaderField: "Range")

        queue.async {
            let startLoad = CACurrentMediaTime()
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, responce, error in
                if let data = data {
                    let endLoad = CACurrentMediaTime()
                    self?.currentBandwidth = stream.bandWidth / (endLoad - startLoad) * 8
                    if let masterData = self?.mastersData[bitRate] {
                        let fileURLWithPath = NSTemporaryDirectory().appending(segment.uri)
                        let tempFileURL = URL(fileURLWithPath: fileURLWithPath)
                        self?.tempFileURL = tempFileURL
                        try? (masterData + data).write(to: tempFileURL)
                        self?.currentItem?.presentationSize = stream.resolution
                        self?.readingData(at: tempFileURL, isEndItem: isEndItem)
                    } else {
                        self?.mastersData[bitRate] = data
                        self?.loadSegment()
                    }
                } else if let error = error {
                    Logger.shared.log("HLSPlayer", "Error loading segment \(error)")
                }
            }
            task.resume()
        }
    }

    func currentBitRate(at item: HLSPlayerItem) -> Int {
        if item.preferredPeakBitRate == 0.0 {
            var bitRate = 0
            if currentBandwidth == 0 {
                if bitRate == 0 {
                    item.streams.forEach { (key, value) in
                        if key > bitRate {
                            bitRate = key
                        }
                    }
                }
            } else {
                item.streams.forEach { (key, value) in
                    if Double(key) < currentBandwidth && key > bitRate {
                        bitRate = key
                    }
                }
                if bitRate == 0 {
                    item.streams.forEach { (key, value) in
                        if bitRate > key || bitRate == 0 {
                            bitRate = key
                        }
                    }
                }
            }
            return bitRate
        } else {
            return Int(item.preferredPeakBitRate)
        }
    }

    func getReader(at asset: AVURLAsset) -> AVAssetReader? {
        if let reader = reader {
            return reader
        }
        guard let reader = try? AVAssetReader(asset: asset) else {
            return nil
        }
        return reader
    }

    func readingData(at tempURL: URL, isEndItem: Bool) {
        currentSegmentNumber += 1

        let asset = AVURLAsset(url: tempURL)
        guard let reader = getReader(at: asset) else {
            try? fileManager.removeItem(at: tempURL)
            Logger.shared.log("HLSPlayer", "Error create AVassetReader")
            return
        }

        if let audioOutput = audioOutput.track(at: asset) {
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
            }
        }

        if let videoOutput = videoOutput.track(at: asset) {
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
            }
        }

        reader.startReading()

        let group = DispatchGroup()
        reader.outputs.forEach { output in
            switch output.mediaType {
            case .audio:
//                queueAudio.async { [weak self] in
                    group.enter()
//                    while let sampleBuffer = output.copyNextSampleBuffer() {
//                        if self?.audioOutput.rendering(at: sampleBuffer) != true {
//                            break
//                        }
//                    }
                    group.leave()
//                }
            case .video:
                queueVideo.async { [weak self] in
                    group.enter()
                    while let sampleBuffer = output.copyNextSampleBuffer() {
                        if self?.layerDelegate?.rendering(at: sampleBuffer) != true {
                            break
                        }
                    }
                    group.leave()
                }
            default:
                return
            }
        }

        group.wait()
        try? fileManager.removeItem(at: tempURL)
        if isEndItem {
            currentSegmentNumber = -1
            switch actionAtItemEnd {
            case .pause:
                pause()
            case .replay:
                play()
            }
            NotificationCenter.default.post(name: Notification.Name("HLSPlayeItemDidPlayToEndTime"), object: nil)
            loadSegment()
        }
    }
}
