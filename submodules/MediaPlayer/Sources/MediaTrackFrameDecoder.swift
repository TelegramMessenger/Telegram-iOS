
protocol MediaTrackFrameDecoder {
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame?
    func takeQueuedFrame() -> MediaTrackFrame?
    func takeRemainingFrame() -> MediaTrackFrame?
    func reset()
}
