import Foundation

struct ProtoTransportState {
    var connected: Bool
}

final class ProtoTransport {
    func update(paths: [ProtoPath]) -> ProtoTransportState {
        return ProtoTransportState(connected: false)
    }
}
