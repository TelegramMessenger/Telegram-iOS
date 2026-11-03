import COgg
import Foundation

public enum OggWriterError: Swift.Error { case cantCreateFile }

/// Streaming Ogg container writer for a single Opus logical bitstream. Emits the
/// two mandatory header pages (OpusHead, OpusTags) on init, one audio packet per
/// `writePacket`, and a final flushed page on `finish`. Pages are written to disk
/// as they emit, so peak memory is bounded to roughly one Ogg page.
///
/// EOS is set on the last real audio packet (not an extra empty packet), so the
/// decoder sees exactly the samples provided via `writePacket`.
public final class OggOpusWriter {
    private var stream = ogg_stream_state()
    private let handle: FileHandle
    private var packetNo: Int64 = 0
    private var granulePos: Int64 = 0
    private let preSkip = 312                    // 6.5 ms @ 48 kHz, Opus default

    // Buffer for the most-recent audio packet so finish() can mark it EOS.
    private var pendingBytes: [UInt8] = []
    private var pendingGranule: Int64 = 0
    private var hasPending = false

    public init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let h = try? FileHandle(forWritingTo: url) else {
            throw OggWriterError.cantCreateFile
        }
        handle = h
        ogg_stream_init(&stream, Int32.random(in: 1...Int32.max))
        writeOpusHead()
        writeOpusTags()
    }

    /// Appends one encoded audio packet. `samples` is the decoded sample count this
    /// packet represents (960 for a 20 ms frame), used to advance granulepos.
    public func writePacket(_ bytes: Data, samples: Int) {
        granulePos += Int64(samples)
        // Flush the previously-buffered packet (not EOS) before buffering this one.
        if hasPending {
            submitBytes(pendingBytes, granule: pendingGranule, bos: false, eos: false, flush: false)
        }
        pendingBytes = [UInt8](bytes)
        pendingGranule = granulePos
        hasPending = true
    }

    /// Marks the last buffered audio packet as EOS, flushes all pending pages, and
    /// closes the file. Must be called exactly once after all `writePacket` calls.
    public func finish() {
        if hasPending {
            // EOS goes on the last real audio packet — no extra empty packet.
            submitBytes(pendingBytes, granule: pendingGranule, bos: false, eos: true, flush: true)
            hasPending = false
        } else {
            // No audio packets were written (e.g. record-then-instant-stop). Emit a
            // zero-length EOS packet so the file still terminates with an EOS-flagged
            // page — an Ogg Opus stream MUST end with one (RFC 7845 §3); otherwise a
            // decoder treats the file as truncated.
            submitBytes([], granule: 0, bos: false, eos: true, flush: true)
        }
        try? handle.close()
        ogg_stream_clear(&stream)
    }

    // MARK: - Header packets

    private func writeOpusHead() {
        var h = [UInt8]()
        h.append(contentsOf: Array("OpusHead".utf8))   // magic (8)
        h.append(1)                                     // version
        h.append(1)                                     // channel count (mono)
        h.append(UInt8(preSkip & 0xFF)); h.append(UInt8((preSkip >> 8) & 0xFF))  // pre-skip LE
        appendLE32(&h, 48_000)                          // input sample rate LE
        h.append(0); h.append(0)                        // output gain
        h.append(0)                                     // channel mapping family
        submitBytes(h, granule: 0, bos: true, eos: false, flush: true)
    }

    private func writeOpusTags() {
        var t = [UInt8]()
        t.append(contentsOf: Array("OpusTags".utf8))    // magic (8)
        let vendor = Array("tgwatch".utf8)
        appendLE32(&t, UInt32(vendor.count)); t.append(contentsOf: vendor)
        appendLE32(&t, 0)                               // user comment list length
        submitBytes(t, granule: 0, bos: false, eos: false, flush: true)
    }

    // MARK: - libogg plumbing

    private func submitBytes(_ bytes: [UInt8], granule: Int64, bos: Bool, eos: Bool, flush: Bool) {
        var buf = bytes
        let byteCount = buf.count
        buf.withUnsafeMutableBufferPointer { p in
            var pkt = ogg_packet()
            pkt.packet = p.baseAddress              // libogg copies this immediately
            pkt.bytes = byteCount
            pkt.b_o_s = bos ? 1 : 0
            pkt.e_o_s = eos ? 1 : 0
            pkt.granulepos = granule
            pkt.packetno = packetNo
            ogg_stream_packetin(&stream, &pkt)
        }
        packetNo += 1
        drain(flush: flush)
    }

    private func drain(flush: Bool) {
        var page = ogg_page()
        while true {
            let r = flush ? ogg_stream_flush(&stream, &page) : ogg_stream_pageout(&stream, &page)
            if r == 0 { break }
            write(page)
        }
    }

    private func write(_ page: ogg_page) {
        handle.write(Data(bytes: page.header!, count: page.header_len))
        handle.write(Data(bytes: page.body!, count: page.body_len))
    }

    private func appendLE32(_ arr: inout [UInt8], _ v: UInt32) {
        arr.append(UInt8(v & 0xFF)); arr.append(UInt8((v >> 8) & 0xFF))
        arr.append(UInt8((v >> 16) & 0xFF)); arr.append(UInt8((v >> 24) & 0xFF))
    }
}
