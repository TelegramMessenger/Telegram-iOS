
protocol MediaTrackFrameDecoder {
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame?
    func reset()
}
