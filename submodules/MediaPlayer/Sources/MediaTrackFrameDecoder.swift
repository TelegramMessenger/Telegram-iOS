
protocol MediaTrackFrameDecoder {
    func send(frame: MediaTrackDecodableFrame) -> Bool
    func decode() -> MediaTrackFrame?
    func takeQueuedFrame() -> MediaTrackFrame?
    func takeRemainingFrame() -> MediaTrackFrame?
    func reset()
    func sendEndToDecoder() -> Bool
}
