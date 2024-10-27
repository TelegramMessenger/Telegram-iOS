import Foundation

struct HLSPlayerStreamEntity {
    let bandWidth: Double
    let resolution: CGSize
    let codecs: String?
    let frameRate: Double?
    let playlist: HLSPlayerPlaylistEntity
}
