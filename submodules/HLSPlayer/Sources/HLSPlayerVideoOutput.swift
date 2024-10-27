import AVFoundation

final class HLSPlayerVideoOutput {

    func track(at asset: AVAsset) -> AVAssetReaderTrackOutput? {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let outputSettings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: track.naturalSize.width,
            kCVPixelBufferHeightKey as String: track.naturalSize.height,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        return output
    }
}
