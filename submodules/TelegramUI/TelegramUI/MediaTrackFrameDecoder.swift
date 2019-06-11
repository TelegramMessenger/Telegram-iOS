
protocol MediaTrackFrameDecoder {
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame?
    func takeRemainingFrame() -> MediaTrackFrame?
    func reset()
}
