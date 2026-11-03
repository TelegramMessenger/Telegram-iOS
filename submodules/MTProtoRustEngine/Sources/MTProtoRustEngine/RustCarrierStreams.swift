import Foundation
import MTProtoEngineFFI
import WebProxyTransport

final class RustCarrierStreams {
    private let engine: OpaquePointer
    private let queue = DispatchQueue(label: "org.telegram.MTProtoRust.carrier")
    private var streams: [UInt64: WebProxyRawStream] = [:]
    private var withheld: [UInt64: Int] = [:]

    init(engine: OpaquePointer) {
        self.engine = engine
    }

    func open(stream: UInt64) {
        self.queue.async { [self] in
            let engine = self.engine
            let raw = WebProxyTransport.shared.openRawStream(timeout: 12.0, queue: self.queue, opened: { [weak self] in
                guard self?.streams[stream] != nil else {
                    return
                }
                mt_stream_opened(engine, stream)
            }, received: { [weak self] data in
                guard let self = self, let raw = self.streams[stream] else {
                    return
                }
                let more = data.withUnsafeBytes { bytes -> Bool in
                    return mt_stream_received(engine, stream, MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count)) != 0
                }
                if let withheld = self.withheld[stream] {
                    self.withheld[stream] = withheld + data.count
                } else if more {
                    raw.consumed(data.count)
                } else {
                    self.withheld[stream] = data.count
                }
            }, sent: { [weak self] count in
                guard self?.streams[stream] != nil else {
                    return
                }
                mt_stream_sent(engine, stream, count)
            }, closed: { [weak self] error in
                guard let self = self, self.streams.removeValue(forKey: stream) != nil else {
                    return
                }
                self.withheld.removeValue(forKey: stream)
                let text = error.map { "\($0)" } ?? ""
                text.withCString { pointer in
                    mt_stream_closed(engine, stream, MTString(data: pointer, length: strlen(pointer)))
                }
            })
            self.streams[stream] = raw
        }
    }

    func write(stream: UInt64, data: Data) {
        self.queue.async {
            guard let raw = self.streams[stream] else {
                return
            }
            raw.write(data)
        }
    }

    func close(stream: UInt64) {
        self.queue.async {
            self.withheld.removeValue(forKey: stream)
            self.streams.removeValue(forKey: stream)?.close()
        }
    }

    func resume(stream: UInt64) {
        self.queue.async {
            if let withheld = self.withheld.removeValue(forKey: stream) {
                self.streams[stream]?.consumed(withheld)
            }
        }
    }
}
