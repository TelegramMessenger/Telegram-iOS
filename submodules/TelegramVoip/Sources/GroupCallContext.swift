import Foundation
import SwiftSignalKit
import TgVoipWebrtc

private final class ContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueueWebrtc {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func dispatch(after seconds: Double, block f: @escaping () -> Void) {
        self.queue.after(seconds, f)
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}

private struct ParsedJoinPayload {
    var payload: String
    var audioSsrc: UInt32
}

private func parseSdpIntoJoinPayload(sdp: String) -> ParsedJoinPayload? {
    let lines = sdp.components(separatedBy: "\n")
    
    var videoLines: [String] = []
    var audioLines: [String] = []
    var isAudioLine = false
    var isVideoLine = false
    for line in lines {
        if line.hasPrefix("m=audio") {
            isAudioLine = true
            isVideoLine = false
        } else if line.hasPrefix("m=video") {
            isVideoLine = true
            isAudioLine = false
        }
        
        if isAudioLine {
            audioLines.append(line)
        } else if isVideoLine {
            videoLines.append(line)
        }
    }
    
    func getLines(prefix: String) -> [String] {
        var result: [String] = []
        for line in lines {
            if line.hasPrefix(prefix) {
                var cleanLine = String(line[line.index(line.startIndex, offsetBy: prefix.count)...])
                if cleanLine.hasSuffix("\r") {
                    cleanLine.removeLast()
                }
                result.append(cleanLine)
            }
        }
        return result
    }
    
    func getLines(prefix: String, isAudio: Bool) -> [String] {
        var result: [String] = []
        for line in (isAudio ? audioLines : videoLines) {
            if line.hasPrefix(prefix) {
                var cleanLine = String(line[line.index(line.startIndex, offsetBy: prefix.count)...])
                if cleanLine.hasSuffix("\r") {
                    cleanLine.removeLast()
                }
                result.append(cleanLine)
            }
        }
        return result
    }
    
    var audioSources: [Int] = []
    for line in getLines(prefix: "a=ssrc:", isAudio: true) {
        let scanner = Scanner(string: line)
        if #available(iOS 13.0, *) {
            if let ssrc = scanner.scanInt() {
                if !audioSources.contains(ssrc) {
                    audioSources.append(ssrc)
                }
            }
        }
    }
    
    guard let ssrc = audioSources.first else {
        return nil
    }
    
    guard let ufrag = getLines(prefix: "a=ice-ufrag:").first else {
        return nil
    }
    guard let pwd = getLines(prefix: "a=ice-pwd:").first else {
        return nil
    }
    
    var resultPayload: [String: Any] = [:]
    
    var fingerprints: [[String: Any]] = []
    for line in getLines(prefix: "a=fingerprint:") {
        let components = line.components(separatedBy: " ")
        if components.count != 2 {
            continue
        }
        fingerprints.append([
            "hash": components[0],
            "fingerprint": components[1],
            "setup": "active"
        ])
    }
    
    resultPayload["fingerprints"] = fingerprints
    
    resultPayload["ufrag"] = ufrag
    resultPayload["pwd"] = pwd
    
    resultPayload["ssrc"] = ssrc
    
    guard let payloadData = try? JSONSerialization.data(withJSONObject: resultPayload, options: []) else {
        return nil
    }
    guard let payloadString = String(data: payloadData, encoding: .utf8) else {
        return nil
    }
    
    return ParsedJoinPayload(
        payload: payloadString,
        audioSsrc: UInt32(ssrc)
    )
}

private func parseJoinResponseIntoSdp(sessionId: UInt32, mainStreamAudioSsrc: UInt32, payload: String, isAnswer: Bool, otherSsrcs: [UInt32]) -> String? {
    guard let payloadData = payload.data(using: .utf8) else {
        return nil
    }
    guard let jsonPayload = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
        return nil
    }
    
    guard let transport = jsonPayload["transport"] as? [String: Any] else {
        return nil
    }
    guard let pwd = transport["pwd"] as? String else {
        return nil
    }
    guard let ufrag = transport["ufrag"] as? String else {
        return nil
    }
    
    struct ParsedFingerprint {
        var hashValue: String
        var fingerprint: String
        var setup: String
    }
    
    var fingerprints: [ParsedFingerprint] = []
    guard let fingerprintsValue = transport["fingerprints"] as? [[String: Any]] else {
        return nil
    }
    for fingerprintValue in fingerprintsValue {
        guard let hashValue = fingerprintValue["hash"] as? String else {
            continue
        }
        guard let fingerprint = fingerprintValue["fingerprint"] as? String else {
            continue
        }
        guard let setup = fingerprintValue["setup"] as? String else {
            continue
        }
        fingerprints.append(ParsedFingerprint(
            hashValue: hashValue,
            fingerprint: fingerprint,
            setup: setup
        ))
    }
    
    struct ParsedCandidate {
        var port: String
        var `protocol`: String
        var network: String
        var generation: String
        var id: String
        var component: String
        var foundation: String
        var priority: String
        var ip: String
        var type: String
        var tcpType: String?
        var relAddr: String?
        var relPort: String?
    }
    
    var candidates: [ParsedCandidate] = []
    guard let candidatesValue = transport["candidates"] as? [[String: Any]] else {
        return nil
    }
    for candidateValue in candidatesValue {
        guard let port = candidateValue["port"] as? String else {
            continue
        }
        guard let `protocol` = candidateValue["protocol"] as? String else {
            continue
        }
        guard let network = candidateValue["network"] as? String else {
            continue
        }
        guard let generation = candidateValue["generation"] as? String else {
            continue
        }
        guard let id = candidateValue["id"] as? String else {
            continue
        }
        guard let component = candidateValue["component"] as? String else {
            continue
        }
        guard let foundation = candidateValue["foundation"] as? String else {
            continue
        }
        guard let priority = candidateValue["priority"] as? String else {
            continue
        }
        guard let ip = candidateValue["ip"] as? String else {
            continue
        }
        guard let type = candidateValue["type"] as? String else {
            continue
        }
        
        let tcpType = candidateValue["tcptype"] as? String
        
        let relAddr = candidateValue["rel-addr"] as? String
        let relPort = candidateValue["rel-port"] as? String
        
        candidates.append(ParsedCandidate(
            port: port,
            protocol: `protocol`,
            network: network,
            generation: generation,
            id: id,
            component: component,
            foundation: foundation,
            priority: priority,
            ip: ip,
            type: type,
            tcpType: tcpType,
            relAddr: relAddr,
            relPort: relPort
        ))
    }
    
    struct StreamSpec {
        var isMain: Bool
        var audioSsrc: Int
        var isRemoved: Bool
    }
    
    func createSdp(sessionId: UInt32, bundleStreams: [StreamSpec]) -> String {
        var sdp = ""
        func appendSdp(_ string: String) {
            if !sdp.isEmpty {
                sdp.append("\n")
            }
            sdp.append(string)
        }
        
        appendSdp("v=0")
        appendSdp("o=- \(sessionId) 2 IN IP4 0.0.0.0")
        appendSdp("s=-")
        appendSdp("t=0 0")
        
        var bundleString = "a=group:BUNDLE"
        for stream in bundleStreams {
            bundleString.append(" ")
            let audioMid: String
            if stream.isMain {
                audioMid = "0"
            } else {
                audioMid = "audio\(stream.audioSsrc)"
            }
            bundleString.append("\(audioMid)")
        }
        appendSdp(bundleString)
        
        appendSdp("a=ice-lite")
        
        for stream in bundleStreams {
            let audioMid: String
            if stream.isMain {
                audioMid = "0"
            } else {
                audioMid = "audio\(stream.audioSsrc)"
            }
            
            appendSdp("m=audio \(stream.isMain ? "1" : "0") RTP/SAVPF 111 126")
            if stream.isMain {
                appendSdp("c=IN IP4 0.0.0.0")
            }
            appendSdp("a=mid:\(audioMid)")
            if stream.isRemoved {
                appendSdp("a=inactive")
            } else {
                if stream.isMain {
                    appendSdp("a=ice-ufrag:\(ufrag)")
                    appendSdp("a=ice-pwd:\(pwd)")
                    
                    for fingerprint in fingerprints {
                        appendSdp("a=fingerprint:\(fingerprint.hashValue) \(fingerprint.fingerprint)")
                        appendSdp("a=setup:passive")
                    }
                    
                    for candidate in candidates {
                        var candidateString = "a=candidate:"
                        candidateString.append("\(candidate.foundation) ")
                        candidateString.append("\(candidate.component) ")
                        var protocolValue = candidate.protocol
                        if protocolValue == "ssltcp" {
                            protocolValue = "tcp"
                        }
                        candidateString.append("\(protocolValue) ")
                        candidateString.append("\(candidate.priority) ")
                        
                        let ip = candidate.ip
                        candidateString.append("\(ip) ")
                        candidateString.append("\(candidate.port) ")
                        
                        candidateString.append("typ \(candidate.type) ")
                        
                        switch candidate.type {
                        case "srflx", "prflx", "relay":
                            if let relAddr = candidate.relAddr, let relPort = candidate.relPort {
                                candidateString.append("raddr \(relAddr) rport \(relPort) ")
                            }
                            break
                        default:
                            break
                        }
                        
                        if protocolValue == "tcp" {
                            guard let tcpType = candidate.tcpType else {
                                continue
                            }
                            candidateString.append("tcptype \(tcpType) ")
                        }
                        
                        candidateString.append("generation \(candidate.generation)")
                        
                        appendSdp(candidateString)
                    }
                }
                
                appendSdp("a=rtpmap:111 opus/48000/2")
                appendSdp("a=rtpmap:126 telephone-event/8000")
                appendSdp("a=fmtp:111 minptime=10; useinbandfec=1; usedtx=1")
                appendSdp("a=rtcp:1 IN IP4 0.0.0.0")
                appendSdp("a=rtcp-mux")
                appendSdp("a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level")
                appendSdp("a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time")
                appendSdp("a=extmap:5 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01")
                appendSdp("a=rtcp-fb:111 transport-cc")
                
                if isAnswer {
                    appendSdp("a=recvonly")
                } else {
                    if stream.isMain {
                        appendSdp("a=sendrecv")
                    } else {
                        appendSdp("a=sendonly")
                        appendSdp("a=bundle-only")
                    }
                    
                    appendSdp("a=ssrc-group:FID \(stream.audioSsrc)")
                    appendSdp("a=ssrc:\(stream.audioSsrc) cname:stream\(stream.audioSsrc)")
                    appendSdp("a=ssrc:\(stream.audioSsrc) msid:stream\(stream.audioSsrc) audio\(stream.audioSsrc)")
                    appendSdp("a=ssrc:\(stream.audioSsrc) mslabel:audio\(stream.audioSsrc)")
                    appendSdp("a=ssrc:\(stream.audioSsrc) label:audio\(stream.audioSsrc)")
                }
            }
        }
        
        appendSdp("")
        
        return sdp
    }
    
    var bundleStreams: [StreamSpec] = []
    bundleStreams.append(StreamSpec(
        isMain: true,
        audioSsrc: Int(mainStreamAudioSsrc),
        isRemoved: false
    ))
    
    for ssrc in otherSsrcs {
        bundleStreams.append(StreamSpec(
            isMain: false,
            audioSsrc: Int(ssrc),
            isRemoved: false
        ))
    }
    
    /*var bundleStreams: [StreamSpec] = []
    if let currentState = currentState {
        for item in currentState.items {
            let isRemoved = !streams.contains(where: { $0.audioSsrc == item.audioSsrc })
            bundleStreams.append(StreamSpec(
                isMain: item.audioSsrc == mainStreamAudioSsrc,
                audioSsrc: item.audioSsrc,
                videoSsrc: item.videoSsrc,
                isRemoved: isRemoved
            ))
        }
    }
    
    for stream in streams {
        if bundleStreams.contains(where: { $0.audioSsrc == stream.audioSsrc }) {
            continue
        }
        bundleStreams.append(stream)
    }*/
    
    return createSdp(sessionId: sessionId, bundleStreams: bundleStreams)
}

public final class OngoingGroupCallContext {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public struct MemberState: Equatable {
        public var isSpeaking: Bool
    }
    
    private final class Impl {
        let queue: Queue
        let context: GroupCallThreadLocalContext
        
        let sessionId = UInt32.random(in: 0 ..< UInt32(Int32.max))
        var mainStreamAudioSsrc: UInt32?
        var initialAnswerPayload: String?
        var otherSsrcs: [UInt32] = []
        
        let joinPayload = Promise<String>()
        let networkState = ValuePromise<NetworkState>(.connecting, ignoreRepeated: true)
        let isMuted = ValuePromise<Bool>(true, ignoreRepeated: true)
        let memberStates = ValuePromise<[UInt32: MemberState]>([:], ignoreRepeated: true)
        
        init(queue: Queue) {
            self.queue = queue
            
            var networkStateUpdatedImpl: ((GroupCallNetworkState) -> Void)?
            
            self.context = GroupCallThreadLocalContext(queue: ContextQueueImpl(queue: queue), relaySdpAnswer: { _ in
            }, incomingVideoStreamListUpdated: { _ in
            }, videoCapturer: nil,
            networkStateUpdated: { state in
                networkStateUpdatedImpl?(state)
            })
            
            let queue = self.queue
            
            networkStateUpdatedImpl = { [weak self] state in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let mappedState: NetworkState
                    switch state {
                    case .connecting:
                        mappedState = .connecting
                    case .connected:
                        mappedState = .connected
                    @unknown default:
                        mappedState = .connecting
                    }
                    strongSelf.networkState.set(mappedState)
                }
            }
            
            self.context.emitOffer(adjustSdp: { sdp in
                return sdp
            }, completion: { [weak self] offerSdp in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    if let payload = parseSdpIntoJoinPayload(sdp: offerSdp) {
                        strongSelf.mainStreamAudioSsrc = payload.audioSsrc
                        strongSelf.joinPayload.set(.single(payload.payload))
                    }
                }
            })
        }
        
        func setJoinResponse(payload: String, ssrcs: [UInt32]) {
            guard let mainStreamAudioSsrc = self.mainStreamAudioSsrc else {
                return
            }
            if let sdp = parseJoinResponseIntoSdp(sessionId: self.sessionId, mainStreamAudioSsrc: mainStreamAudioSsrc, payload: payload, isAnswer: true, otherSsrcs: []) {
                self.initialAnswerPayload = payload
                self.context.setOfferSdp(sdp, isPartial: true)
                self.addSsrcs(ssrcs: ssrcs)
            }
        }
        
        func addSsrcs(ssrcs: [UInt32]) {
            if ssrcs.isEmpty {
                return
            }
            guard let mainStreamAudioSsrc = self.mainStreamAudioSsrc else {
                return
            }
            guard let initialAnswerPayload = self.initialAnswerPayload else {
                return
            }
            let mappedSsrcs = ssrcs
            var otherSsrcs = self.otherSsrcs
            for ssrc in mappedSsrcs {
                if ssrc == mainStreamAudioSsrc {
                    continue
                }
                if !otherSsrcs.contains(ssrc) {
                    otherSsrcs.append(ssrc)
                }
            }
            if self.otherSsrcs != otherSsrcs {
                self.otherSsrcs = otherSsrcs
                var memberStatesValue: [UInt32: MemberState] = [:]
                for ssrc in otherSsrcs {
                    memberStatesValue[ssrc] = MemberState(isSpeaking: false)
                }
                self.memberStates.set(memberStatesValue)
                
                if let sdp = parseJoinResponseIntoSdp(sessionId: self.sessionId, mainStreamAudioSsrc: mainStreamAudioSsrc, payload: initialAnswerPayload, isAnswer: false, otherSsrcs: self.otherSsrcs) {
                    self.context.setOfferSdp(sdp, isPartial: false)
                }
            }
        }
        
        func setIsMuted(_ isMuted: Bool) {
            self.isMuted.set(isMuted)
            self.context.setIsMuted(isMuted)
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public var joinPayload: Signal<String, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.joinPayload.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var networkState: Signal<NetworkState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.networkState.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var memberStates: Signal<[UInt32: MemberState], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.memberStates.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var isMuted: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isMuted.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
    
    public func setIsMuted(_ isMuted: Bool) {
        self.impl.with { impl in
            impl.setIsMuted(isMuted)
        }
    }
    
    public func setJoinResponse(payload: String, ssrcs: [UInt32]) {
        self.impl.with { impl in
            impl.setJoinResponse(payload: payload, ssrcs: ssrcs)
        }
    }
    
    public func addSsrcs(ssrcs: [UInt32]) {
        self.impl.with { impl in
            impl.addSsrcs(ssrcs: ssrcs)
        }
    }
}
