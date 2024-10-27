struct HLSPlayerPlaylistEntity {
    let duration: Double
    let sequence: Int
    let segments: [Segment]

    struct Segment {
        let duration: Double
        let byteRange: ByteRange
        let uri: String
    }

    struct ByteRange {
        let length: Int
        let offset: Int
    }
}
