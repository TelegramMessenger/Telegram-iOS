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

private struct ConferenceDescription {
    struct Transport {
        struct Candidate {
            var id: String
            var generation: Int
            var component: String
            var `protocol`: String
            var tcpType: String?
            var ip: String
            var port: Int
            var foundation: String
            var priority: Int
            var type: String
            var network: Int
            var relAddr: String?
            var relPort: Int?
        }
        
        struct Fingerprint {
            var fingerprint: String
            var setup: String
            var hashType: String
        }
        
        var candidates: [Candidate]
        var fingerprints: [Fingerprint]
        var ufrag: String
        var pwd: String
    }
    
    struct ChannelBundle {
        var id: String
        var transport: Transport
    }
    
    struct Content {
        struct Channel {
            struct SsrcGroup {
                var sources: [Int]
                var semantics: String
            }
            
            struct PayloadType {
                var id: Int
                var name: String
                var clockrate: Int
                var channels: Int
                var parameters: [String: Any]?
            }
            
            struct RtpHdrExt {
                var id: Int
                var uri: String
            }
            
            var id: String?
            var endpoint: String
            var channelBundleId: String
            var sources: [Int]
            var ssrcs: [Int]
            var rtpLevelRelayType: String
            var expire: Int?
            var initiator: Bool
            var direction: String
            var ssrcGroups: [SsrcGroup]
            var payloadTypes: [PayloadType]
            var rtpHdrExts: [RtpHdrExt]
        }
        
        var name: String
        var channels: [Channel]
    }
    
    var id: String
    var channelBundles: [ChannelBundle]
    var contents: [Content]
    
    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else {
            assert(false)
            return nil
        }
        self.id = id
        
        var channelBundles: [ChannelBundle] = []
        if let channelBundlesJson = json["channel-bundles"] as? [Any] {
            for channelBundleValue in channelBundlesJson {
                if let channelBundleJson = channelBundleValue as? [String: Any] {
                    if let channelBundle = ChannelBundle(json: channelBundleJson) {
                        channelBundles.append(channelBundle)
                    }
                }
            }
        }
        self.channelBundles = channelBundles
        
        var contents: [Content] = []
        if let contentsJson = json["contents"] as? [Any] {
            for contentValue in contentsJson {
                if let contentJson = contentValue as? [String: Any] {
                    if let content = Content(json: contentJson) {
                        contents.append(content)
                    }
                }
            }
        }
        self.contents = contents
    }
}

private extension ConferenceDescription.Transport.Candidate {
    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else {
            assert(false)
            return nil
        }
        self.id = id
        
        if let generationString = json["generation"] as? String, let generation = Int(generationString) {
            self.generation = generation
        } else {
            self.generation = 0
        }
        
        guard let component = json["component"] as? String else {
            assert(false)
            return nil
        }
        self.component = component
        
        guard let `protocol` = json["protocol"] as? String else {
            assert(false)
            return nil
        }
        self.protocol = `protocol`
        
        if let tcpType = json["tcptype"] as? String {
            self.tcpType = tcpType
        } else {
            self.tcpType = nil
        }
        
        guard let ip = json["ip"] as? String else {
            assert(false)
            return nil
        }
        self.ip = ip
        
        guard let portString = json["port"] as? String, let port = Int(portString) else {
            assert(false)
            return nil
        }
        self.port = port
        
        guard let foundation = json["foundation"] as? String else {
            assert(false)
            return nil
        }
        self.foundation = foundation
        
        guard let priorityString = json["priority"] as? String, let priority = Int(priorityString) else {
            assert(false)
            return nil
        }
        self.priority = priority
        
        guard let type = json["type"] as? String else {
            assert(false)
            return nil
        }
        self.type = type
        
        guard let networkString = json["network"] as? String, let network = Int(networkString) else {
            assert(false)
            return nil
        }
        self.network = network
        
        if let relAddr = json["rel-addr"] as? String {
            self.relAddr = relAddr
        } else {
            self.relAddr = nil
        }
        
        if let relPortString = json["rel-port"] as? String, let relPort = Int(relPortString) {
            self.relPort = relPort
        } else {
            self.relPort = nil
        }
    }
}

private extension ConferenceDescription.Transport.Fingerprint {
    init?(json: [String: Any]) {
        guard let fingerprint = json["fingerprint"] as? String else {
            assert(false)
            return nil
        }
        self.fingerprint = fingerprint
        
        guard let setup = json["setup"] as? String else {
            assert(false)
            return nil
        }
        self.setup = setup
        
        guard let hashType = json["hash"] as? String else {
            assert(false)
            return nil
        }
        self.hashType = hashType
    }
}

private extension ConferenceDescription.Transport {
    init?(json: [String: Any]) {
        guard let ufrag = json["ufrag"] as? String else {
            assert(false)
            return nil
        }
        self.ufrag = ufrag
        
        guard let pwd = json["pwd"] as? String else {
            assert(false)
            return nil
        }
        self.pwd = pwd
        
        var candidates: [Candidate] = []
        if let candidatesJson = json["candidates"] as? [Any] {
            for candidateValue in candidatesJson {
                if let candidateJson = candidateValue as? [String: Any] {
                    if let candidate = Candidate(json: candidateJson) {
                        candidates.append(candidate)
                    }
                }
            }
        }
        self.candidates = candidates
        
        var fingerprints: [Fingerprint] = []
        if let fingerprintsJson = json["fingerprints"] as? [Any] {
            for fingerprintValue in fingerprintsJson {
                if let fingerprintJson = fingerprintValue as? [String: Any] {
                    if let fingerprint = Fingerprint(json: fingerprintJson) {
                        fingerprints.append(fingerprint)
                    }
                }
            }
        }
        self.fingerprints = fingerprints
    }
}

private extension ConferenceDescription.ChannelBundle {
    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else {
            assert(false)
            return nil
        }
        self.id = id
        
        guard let transportJson = json["transport"] as? [String: Any] else {
            assert(false)
            return nil
        }
        guard let transport = ConferenceDescription.Transport(json: transportJson) else {
            assert(false)
            return nil
        }
        self.transport = transport
    }
}

private extension ConferenceDescription.Content.Channel.SsrcGroup {
    init?(json: [String: Any]) {
        guard let sources = json["sources"] as? [Int] else {
            assert(false)
            return nil
        }
        self.sources = sources
        
        guard let semantics = json["semantics"] as? String else {
            assert(false)
            return nil
        }
        self.semantics = semantics
    }
}

private extension ConferenceDescription.Content.Channel.PayloadType {
    init?(json: [String: Any]) {
        guard let idString = json["id"] as? String, let id = Int(idString) else {
            assert(false)
            return nil
        }
        self.id = id
        
        guard let name = json["name"] as? String else {
            assert(false)
            return nil
        }
        self.name = name
        
        guard let clockrateString = json["clockrate"] as? String, let clockrate = Int(clockrateString) else {
            assert(false)
            return nil
        }
        self.clockrate = clockrate
        
        guard let channelsString = json["channels"] as? String, let channels = Int(channelsString) else {
            assert(false)
            return nil
        }
        self.channels = channels
        
        self.parameters = json["parameters"] as? [String: Any]
    }
}

private extension ConferenceDescription.Content.Channel.RtpHdrExt {
    init?(json: [String: Any]) {
        guard let idString = json["id"] as? String, let id = Int(idString) else {
            assert(false)
            return nil
        }
        self.id = id
        
        guard let uri = json["uri"] as? String else {
            assert(false)
            return nil
        }
        self.uri = uri
    }
}

private extension ConferenceDescription.Content.Channel {
    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else {
            assert(false)
            return nil
        }
        self.id = id
        
        guard let endpoint = json["endpoint"] as? String else {
            assert(false)
            return nil
        }
        self.endpoint = endpoint
        
        guard let channelBundleId = json["channel-bundle-id"] as? String else {
            assert(false)
            return nil
        }
        self.channelBundleId = channelBundleId
        
        guard let sources = json["sources"] as? [Int] else {
            assert(false)
            return nil
        }
        self.sources = sources
        
        if let ssrcs = json["ssrcs"] as? [Int] {
            self.ssrcs = ssrcs
        } else {
            self.ssrcs = []
        }
        
        guard let rtpLevelRelayType = json["rtp-level-relay-type"] as? String else {
            assert(false)
            return nil
        }
        self.rtpLevelRelayType = rtpLevelRelayType
        
        if let expire = json["expire"] as? Int {
            self.expire = expire
        } else {
            self.expire = nil
        }
        
        guard let initiator = json["initiator"] as? Bool else {
            assert(false)
            return nil
        }
        self.initiator = initiator
        
        guard let direction = json["direction"] as? String else {
            assert(false)
            return nil
        }
        self.direction = direction
        
        var ssrcGroups: [SsrcGroup] = []
        if let ssrcGroupsJson = json["ssrc-groups"] as? [Any] {
            for ssrcGroupValue in ssrcGroupsJson {
                if let ssrcGroupJson = ssrcGroupValue as? [String: Any] {
                    if let ssrcGroup = SsrcGroup(json: ssrcGroupJson) {
                        ssrcGroups.append(ssrcGroup)
                    }
                }
            }
        }
        self.ssrcGroups = ssrcGroups
        
        var payloadTypes: [PayloadType] = []
        if let payloadTypesJson = json["payload-types"] as? [Any] {
            for payloadTypeValue in payloadTypesJson {
                if let payloadTypeJson = payloadTypeValue as? [String: Any] {
                    if let payloadType = PayloadType(json: payloadTypeJson) {
                        payloadTypes.append(payloadType)
                    }
                }
            }
        }
        self.payloadTypes = payloadTypes
        
        var rtpHdrExts: [RtpHdrExt] = []
        if let rtpHdrExtsJson = json["rtp-hdrexts"] as? [Any] {
            for rtpHdrExtValue in rtpHdrExtsJson {
                if let rtpHdrExtJson = rtpHdrExtValue as? [String: Any] {
                    if let rtpHdrExt = RtpHdrExt(json: rtpHdrExtJson) {
                        rtpHdrExts.append(rtpHdrExt)
                    }
                }
            }
        }
        self.rtpHdrExts = rtpHdrExts
    }
}

private extension ConferenceDescription.Content {
    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else {
            assert(false)
            return nil
        }
        self.name = name
        
        var channels: [Channel] = []
        if let channelsJson = json["channels"] as? [Any] {
            for channelValue in channelsJson {
                if let channelJson = channelValue as? [String: Any] {
                    if let channel = Channel(json: channelJson) {
                        channels.append(channel)
                    }
                }
            }
        }
        self.channels = channels
    }
}

private extension ConferenceDescription.Content.Channel.SsrcGroup {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["sources"] = self.sources
        result["semantics"] = self.semantics
        
        return result
    }
}

private extension ConferenceDescription.Content.Channel.PayloadType {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["id"] = self.id
        result["name"] = self.name
        result["channels"] = self.channels
        result["clockrate"] = self.clockrate
        if let parameters = self.parameters {
            result["parameters"] = parameters
        }
        
        return result
    }
}

private extension ConferenceDescription.Content.Channel.RtpHdrExt {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["id"] = self.id
        result["uri"] = self.uri
        
        return result
    }
}

private extension ConferenceDescription.Content.Channel {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let id = self.id {
            result["id"] = id
        }
        result["expire"] = self.expire ?? 10
        result["initiator"] = self.initiator
        result["endpoint"] = self.endpoint
        result["direction"] = self.direction
        result["channel-bundle-id"] = self.channelBundleId
        result["rtp-level-relay-type"] = self.rtpLevelRelayType
        if !self.sources.isEmpty {
            result["sources"] = self.sources
        }
        if !self.ssrcs.isEmpty {
            result["ssrcs"] = self.ssrcs
        }
        if !self.ssrcGroups.isEmpty {
            result["ssrc-groups"] = self.ssrcGroups.map { $0.outgoingColibriDescription() }
        }
        if !self.payloadTypes.isEmpty {
            result["payload-types"] = self.payloadTypes.map { $0.outgoingColibriDescription() }
        }
        if !self.rtpHdrExts.isEmpty {
            result["rtp-hdrexts"] = self.rtpHdrExts.map { $0.outgoingColibriDescription() }
        }
        
        return result
    }
}

private extension ConferenceDescription.Content {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["name"] = self.name
        result["channels"] = self.channels.map { $0.outgoingColibriDescription() }
        
        return result
    }
}

private extension ConferenceDescription.Transport.Fingerprint {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["fingerprint"] = self.fingerprint
        result["setup"] = self.setup
        result["hash"] = self.hashType
        
        return result
    }
}

private extension ConferenceDescription.Transport.Candidate {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["id"] = self.id
        result["generation"] = self.generation
        result["component"] = self.component
        result["protocol"] = self.protocol
        if let tcpType = self.tcpType {
            result["tcptype"] = tcpType
        }
        result["ip"] = self.ip
        result["port"] = self.port
        result["foundation"] = self.foundation
        result["priority"] = self.priority
        result["type"] = self.type
        result["network"] = self.network
        if let relAddr = self.relAddr {
            result["rel-addr"] = relAddr
        }
        if let relPort = self.relPort {
            result["rel-port"] = relPort
        }
        
        return result
    }
}

private extension ConferenceDescription.Transport {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["xmlns"] = "urn:xmpp:jingle:transports:ice-udp:1"
        result["rtcp-mux"] = true
        
        if !self.ufrag.isEmpty {
            result["ufrag"] = self.ufrag
            result["pwd"] = self.pwd
        }
        
        if !self.fingerprints.isEmpty {
            result["fingerprints"] = self.fingerprints.map { $0.outgoingColibriDescription() }
        }
        
        if !self.candidates.isEmpty {
            result["candidates"] = self.candidates.map { $0.outgoingColibriDescription() }
        }
        
        return result
    }
}

private extension ConferenceDescription.ChannelBundle {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["id"] = self.id
        result["transport"] = self.transport.outgoingColibriDescription()
        
        return result
    }
}

private extension ConferenceDescription {
    func outgoingColibriDescription() -> [String: Any] {
        var result: [String: Any] = [:]
        
        result["id"] = self.id
        result["contents"] = self.contents.map { $0.outgoingColibriDescription() }
        result["channel-bundles"] = self.channelBundles.map { $0.outgoingColibriDescription() }
        
        return result
    }
    
    func offerSdp(sessionId: UInt32, bundleId: String, bridgeHost: String, transport: ConferenceDescription.Transport, currentSsrcOrder: [Int]) -> (String, [Int])? {
        var otherSsrc: [(Bool, Int, String)] = []
        for content in self.contents {
            for channel in content.channels {
                if channel.endpoint == bundleId {
                    otherSsrc.append(contentsOf: channel.sources.map { ssrc in
                        return (true, ssrc, "stream0")
                    })
                } else {
                    otherSsrc.append(contentsOf: channel.ssrcs.map { ssrc in
                        return (false, ssrc, channel.channelBundleId)
                    })
                }
            }
        }
        otherSsrc.sort(by: { lhs, rhs in
            /*if let previousLhsIndex = currentSsrcOrder.firstIndex(of: lhs.1), let previousRhsIndex = currentSsrcOrder.firstIndex(of: rhs.1) {
                return previousLhsIndex < previousRhsIndex
            }
            if currentSsrcOrder.contains(lhs.1) != currentSsrcOrder.contains(rhs.1) {
                return currentSsrcOrder.contains(lhs.1)
            }*/
            if lhs.0 != rhs.0 {
                return lhs.0
            } else {
                return lhs.1 < rhs.1
            }
        })
        
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
        
        /*appendSdp("a=group:BUNDLE audio0")
        do {
            appendSdp("m=audio 1 RTP/SAVPF 111 103 104 126")
            appendSdp("c=IN IP4 0.0.0.0")
            appendSdp("a=rtpmap:111 opus/48000/2")
            appendSdp("a=rtpmap:103 ISAC/16000")
            appendSdp("a=rtpmap:104 ISAC/32000")
            appendSdp("a=rtpmap:126 telephone-event/8000")
            appendSdp("a=fmtp:111 minptime=10; useinbandfec=1")
            appendSdp("a=rtcp:1 IN IP4 0.0.0.0")
            appendSdp("a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level")
            appendSdp("a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time")
            appendSdp("a=mid:audio0")
            appendSdp("a=sendrecv")
            appendSdp("a=ice-ufrag:\(transport.ufrag)")
            appendSdp("a=ice-pwd:\(transport.pwd)")
            for fingerprint in transport.fingerprints {
                appendSdp("a=fingerprint:\(fingerprint.hashType) \(fingerprint.fingerprint)")
                appendSdp("a=setup:\(fingerprint.setup)")
            }
            
            for candidate in transport.candidates {
                var candidateString = "a=candidate:"
                candidateString.append("\(candidate.foundation) ")
                candidateString.append("\(candidate.component) ")
                var protocolValue = candidate.protocol
                if protocolValue == "ssltcp" {
                    protocolValue = "tcp"
                }
                candidateString.append("\(protocolValue) ")
                candidateString.append("\(candidate.priority) ")
                
                var ip = candidate.ip
                ip = bridgeHost
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
            
            for ssrc in bridgeSources {
                appendSdp("a=ssrc:\(ssrc) cname:cname\(ssrc)")
                appendSdp("a=ssrc:\(ssrc) msid:stream0 audio0")
                appendSdp("a=ssrc:\(ssrc) mslabel:stream0")
                appendSdp("a=ssrc:\(ssrc) label:audio0")
            }
            
            /*for (ssrc, streamId) in otherSsrc {
                appendSdp("a=ssrc:\(ssrc) cname:cname\(ssrc)")
                appendSdp("a=ssrc:\(ssrc) msid:\(streamId) audio0")
                //appendSdp("a=ssrc:\(ssrc) mslabel:\(streamId)")
                //appendSdp("a=ssrc:\(ssrc) label:\(streamId)")
            }*/
            
            appendSdp("a=rtcp-mux")
        }*/
        
        appendSdp("a=group:BUNDLE audio")
        appendSdp("a=ice-lite")
        
        appendSdp("a=msid-semantic:WMS *")
        
        appendSdp("m=audio 1 RTP/SAVPF 111 103 104 126")
        
        appendSdp("c=IN IP4 0.0.0.0")
        
        appendSdp("a=ice-ufrag:\(transport.ufrag)")
        appendSdp("a=ice-pwd:\(transport.pwd)")
        for fingerprint in transport.fingerprints {
            appendSdp("a=fingerprint:\(fingerprint.hashType) \(fingerprint.fingerprint)")
            appendSdp("a=setup:\(fingerprint.setup)")
        }
        
        for candidate in transport.candidates {
            var candidateString = "a=candidate:"
            candidateString.append("\(candidate.foundation) ")
            candidateString.append("\(candidate.component) ")
            var protocolValue = candidate.protocol
            if protocolValue == "ssltcp" {
                protocolValue = "tcp"
            }
            candidateString.append("\(protocolValue) ")
            candidateString.append("\(candidate.priority) ")
            
            var ip = candidate.ip
            ip = bridgeHost
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
        
        appendSdp("a=rtpmap:111 opus/48000/2")
        appendSdp("a=rtpmap:103 ISAC/16000")
        appendSdp("a=rtpmap:104 ISAC/32000")
        appendSdp("a=rtpmap:126 telephone-event/8000")
        appendSdp("a=fmtp:111 minptime=10; useinbandfec=1")
        appendSdp("a=rtcp:1 IN IP4 0.0.0.0")
        appendSdp("a=rtcp-mux")
        appendSdp("a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level")
        appendSdp("a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time")
        
        appendSdp("a=mid:audio")
        appendSdp("a=sendrecv")
        
        for (_, ssrc, streamId) in otherSsrc {
            appendSdp("a=ssrc-group:FID \(ssrc)")
            appendSdp("a=ssrc:\(ssrc) cname:stream\(streamId)")
            appendSdp("a=ssrc:\(ssrc) msid:stream\(streamId) audio\(streamId)")
            //appendSdp("a=ssrc:\(ssrc) mslabel:stream\(streamId)")
            //appendSdp("a=ssrc:\(ssrc) label:audio\(streamId)")
        }
        
        /*for (isBridge, ssrc, streamId) in otherSsrc {
            let mPort: Int
            if isBridge {
                mPort = 1
            } else {
                mPort = 0
            }
            appendSdp("m=audio \(mPort) RTP/SAVPF 111 103 104 126")
            appendSdp("c=IN IP4 0.0.0.0")
            
            if isBridge {
                appendSdp("a=sendrecv")
            } else {
                appendSdp("a=bundle-only")
                appendSdp("a=sendonly")
            }
            
            appendSdp("a=rtpmap:111 opus/48000/2")
            appendSdp("a=rtpmap:103 ISAC/16000")
            appendSdp("a=rtpmap:104 ISAC/32000")
            appendSdp("a=rtpmap:126 telephone-event/8000")
            appendSdp("a=fmtp:111 minptime=10; useinbandfec=1")
            appendSdp("a=rtcp:1 IN IP4 0.0.0.0")
            appendSdp("a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level")
            appendSdp("a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time")
            appendSdp("a=mid:audio\(ssrc)")
            
            if isBridge {
                for candidate in transport.candidates {
                    var candidateString = "a=candidate:"
                    candidateString.append("\(candidate.foundation) ")
                    candidateString.append("\(candidate.component) ")
                    var protocolValue = candidate.protocol
                    if protocolValue == "ssltcp" {
                        protocolValue = "tcp"
                    }
                    candidateString.append("\(protocolValue) ")
                    candidateString.append("\(candidate.priority) ")
                    
                    var ip = candidate.ip
                    ip = bridgeHost
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
            
            appendSdp("a=ssrc:\(ssrc) cname:stream\(streamId)")
            appendSdp("a=ssrc:\(ssrc) msid:stream\(streamId) audio\(streamId)")
            //appendSdp("a=ssrc:\(ssrc) mslabel:stream\(streamId)")
            //appendSdp("a=ssrc:\(ssrc) label:audio\(streamId)")
            
            appendSdp("a=rtcp-mux")
        }*/
        
        appendSdp("")
        
        return (sdp, otherSsrc.map(\.1))
    }
    
    mutating func updateLocalChannelFromSdpAnswer(bundleId: String, sdpAnswer: String) {
        var maybeAudioChannel: ConferenceDescription.Content.Channel?
        for content in self.contents {
            for channel in content.channels {
                if channel.endpoint == bundleId {
                    maybeAudioChannel = channel
                    break
                }
            }
        }
        
        guard var audioChannel = maybeAudioChannel else {
            assert(false)
            return
        }
        
        let lines = sdpAnswer.components(separatedBy: "\n")
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
        
        /*
         v=0
         o=- 3432551037272164134 2 IN IP4 127.0.0.1
         s=-
         t=0 0
         a=group:BUNDLE audio
         a=msid-semantic: WMS stream0
         m=audio 9 RTP/SAVPF 103 104 126
         c=IN IP4 0.0.0.0
         a=rtcp:9 IN IP4 0.0.0.0
         a=ice-ufrag:XTZl
         a=ice-pwd:GS+K9fcajkZ96gy5hCIyx1BV
         a=ice-options:trickle
         a=fingerprint:sha-256 88:A3:3E:2C:E3:3C:DF:E8:31:1B:59:AA:73:60:D8:EF:E7:FE:0D:F5:B8:F1:79:26:58:A3:D2:93:D9:8C:49:29
         a=setup:active
         a=mid:audio
         a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
         a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
         a=sendrecv
         a=msid:stream0 audio0
         a=rtcp-mux
         a=rtpmap:103 ISAC/16000
         a=rtpmap:104 ISAC/32000
         a=rtpmap:126 telephone-event/8000
         a=ssrc:666769703 cname:g5ORSLYV5oOfoEBX
         a=ssrc:666769703 msid:stream0 audio0
         a=ssrc:666769703 mslabel:stream0
         a=ssrc:666769703 label:audio0
         */
        
        var audioSources: [Int] = []
        for line in getLines(prefix: "a=ssrc:") {
            let scanner = Scanner(string: line)
            if #available(iOS 13.0, *) {
                if let ssrc = scanner.scanInt() {
                    if !audioSources.contains(ssrc) {
                        audioSources.append(ssrc)
                    }
                }
            }
        }
        
        audioChannel.sources = audioSources
        /*audioChannel.ssrcGroups = [ConferenceDescription.Content.Channel.SsrcGroup(
            sources: audioSources,
            semantics: "SIM"
        )]*/
        
        audioChannel.payloadTypes = [
            ConferenceDescription.Content.Channel.PayloadType(
                id: 111,
                name: "opus",
                clockrate: 48000,
                channels: 2,
                parameters: [
                    "fmtp": [
                        "minptime=10;useinbandfec=1"
                    ] as [Any]
                ]
            ),
            ConferenceDescription.Content.Channel.PayloadType(
                id: 103,
                name: "ISAC",
                clockrate: 16000,
                channels: 1
            ),
            ConferenceDescription.Content.Channel.PayloadType(
                id: 104,
                name: "ISAC",
                clockrate: 32000,
                channels: 1
            ),
            ConferenceDescription.Content.Channel.PayloadType(
                id: 126,
                name: "telephone-event",
                clockrate: 8000,
                channels: 1
            )
        ]
        
        audioChannel.rtpHdrExts = [
            ConferenceDescription.Content.Channel.RtpHdrExt(
                id: 1,
                uri: "urn:ietf:params:rtp-hdrext:ssrc-audio-level"
            ),
            ConferenceDescription.Content.Channel.RtpHdrExt(
                id: 3,
                uri: "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time"
            ),
        ]
        
        guard let ufrag = getLines(prefix: "a=ice-ufrag:").first else {
            assert(false)
            return
        }
        guard let pwd = getLines(prefix: "a=ice-pwd:").first else {
            assert(false)
            return
        }
        
        var fingerprints: [ConferenceDescription.Transport.Fingerprint] = []
        for line in getLines(prefix: "a=fingerprint:") {
            let components = line.components(separatedBy: " ")
            if components.count != 2 {
                continue
            }
            fingerprints.append(ConferenceDescription.Transport.Fingerprint(
                fingerprint: components[1],
                setup: "active",
                hashType: components[0]
            ))
        }
        
        outerContents: for i in 0 ..< self.contents.count {
            for j in 0 ..< self.contents[i].channels.count {
                if self.contents[i].channels[j].endpoint == bundleId {
                    self.contents[i].channels[j] = audioChannel
                    break outerContents
                }
            }
        }
        
        let transport = ConferenceDescription.Transport(
            candidates: [],
            fingerprints: fingerprints,
            ufrag: ufrag,
            pwd: pwd
        )
        
        var found = false
        for i in 0 ..< self.channelBundles.count {
            if self.channelBundles[i].id == bundleId {
                self.channelBundles[i].transport = transport
                found = true
                break
            }
        }
        if !found {
            self.channelBundles.append(ConferenceDescription.ChannelBundle(
                id: bundleId,
                transport: transport
            ))
        }
    }
}

private enum HttpError {
    case generic
    case network
    case server(String)
}

private enum HttpMethod {
    case get
    case post([String: Any])
    case patch([String: Any])
}

private func httpJsonRequest<T>(url: String, method: HttpMethod, resultType: T.Type) -> Signal<T, HttpError> {
    return Signal { subscriber in
        guard let url = URL(string: url) else {
            subscriber.putError(.generic)
            return EmptyDisposable
        }
        let completed = Atomic<Bool>(value: false)
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1000.0)
        
        switch method {
        case .get:
            break
        case let .post(data):
            guard let body = try? JSONSerialization.data(withJSONObject: data, options: []) else {
                subscriber.putError(.generic)
                return EmptyDisposable
            }
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            request.httpMethod = "POST"
        case let .patch(data):
            guard let body = try? JSONSerialization.data(withJSONObject: data, options: []) else {
                subscriber.putError(.generic)
                return EmptyDisposable
            }
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            request.httpMethod = "PATCH"
            
            //print("PATCH: \(String(data: body, encoding: .utf8)!)")
        }
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, _, error in
            if let error = error {
                print("\(error)")
                subscriber.putError(.server("\(error)"))
                return
            }
            
            let _ = completed.swap(true)
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? T {
                subscriber.putNext(json)
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        task.resume()
        
        return ActionDisposable {
            if !completed.with({ $0 }) {
                task.cancel()
            }
        }
    }
}

public final class GroupCallContext {
    private final class Impl {
        private let queue: Queue
        private let context: GroupCallThreadLocalContext
        private let disposable = MetaDisposable()
        
        private let colibriHost: String
        private let sessionId: UInt32
        
        private var audioSessionDisposable: Disposable?
        private let pollDisposable = MetaDisposable()
        
        private var conferenceId: String?
        private var localBundleId: String?
        private var localTransport: ConferenceDescription.Transport?
        
        init(queue: Queue, audioSessionActive: Signal<Bool, NoError>) {
            self.queue = queue
            
            self.sessionId = UInt32.random(in: 0 ..< UInt32(Int32.max))
            //self.colibriHost = "192.168.8.118"
            self.colibriHost = "192.168.93.24"
            //self.colibriHost = "51.104.206.109"
            
            var relaySdpAnswerImpl: ((String) -> Void)?
            
            self.context = GroupCallThreadLocalContext(queue: ContextQueueImpl(queue: queue), relaySdpAnswer: { sdpAnswer in
                queue.async {
                    relaySdpAnswerImpl?(sdpAnswer)
                }
            })
            
            relaySdpAnswerImpl = { [weak self] sdpAnswer in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.relaySdpAnswer(sdpAnswer: sdpAnswer)
            }
            
            self.audioSessionDisposable = (audioSessionActive
            |> filter { $0 }
            |> take(1)
            |> deliverOn(queue)).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.requestConference()
            })
        }
        
        deinit {
            self.disposable.dispose()
            self.audioSessionDisposable?.dispose()
            self.pollDisposable.dispose()
        }
        
        func requestConference() {
            self.disposable.set((httpJsonRequest(url: "http://\(self.colibriHost):8080/colibri/conferences/", method: .get, resultType: [Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                if let conferenceJson = result.first as? [String: Any] {
                    if let conferenceId = ConferenceDescription(json: conferenceJson)?.id {
                        strongSelf.disposable.set((httpJsonRequest(url: "http://\(strongSelf.colibriHost):8080/colibri/conferences/\(conferenceId)", method: .get, resultType: [String: Any].self)
                        |> deliverOn(strongSelf.queue)).start(next: { result in
                            guard let strongSelf = self else {
                                return
                            }
                            if let conference = ConferenceDescription(json: result) {
                                strongSelf.allocateChannels(conference: conference)
                            }
                        }))
                    }
                } else {
                    strongSelf.disposable.set((httpJsonRequest(url: "http://\(strongSelf.colibriHost):8080/colibri/conferences/", method: .post([:]), resultType: [String: Any].self)
                    |> deliverOn(strongSelf.queue)).start(next: { result in
                        guard let strongSelf = self else {
                            return
                        }
                        if let conference = ConferenceDescription(json: result) {
                            strongSelf.allocateChannels(conference: conference)
                        }
                    }))
                }
            }))
        }
        
        private var currentSsrcOrder: [Int] = []
        
        func allocateChannels(conference: ConferenceDescription) {
            let bundleId = UUID().uuidString
            
            var conference = conference
            let audioChannel = ConferenceDescription.Content.Channel(
                id: nil,
                endpoint: bundleId,
                channelBundleId: bundleId,
                sources: [],
                ssrcs: [],
                rtpLevelRelayType: "translator",
                expire: 10,
                initiator: true,
                direction: "sendrecv",
                ssrcGroups: [],
                payloadTypes: [],
                rtpHdrExts: []
            )
            
            var foundContent = false
            for i in 0 ..< conference.contents.count {
                if conference.contents[i].name == "audio" {
                    for j in 0 ..< conference.contents[i].channels.count {
                        let channel = conference.contents[i].channels[j]
                        conference.contents[i].channels[j] = ConferenceDescription.Content.Channel(
                            id: channel.id,
                            endpoint: channel.endpoint,
                            channelBundleId: channel.channelBundleId,
                            sources: channel.sources,
                            ssrcs: channel.ssrcs,
                            rtpLevelRelayType: channel.rtpLevelRelayType,
                            expire: channel.expire,
                            initiator: channel.initiator,
                            direction: channel.direction,
                            ssrcGroups: [],
                            payloadTypes: [],
                            rtpHdrExts: []
                        )
                    }
                    conference.contents[i].channels.append(audioChannel)
                    foundContent = true
                    break
                }
            }
            if !foundContent {
                conference.contents.append(ConferenceDescription.Content(
                    name: "audio",
                    channels: [audioChannel]
                ))
            }
            conference.channelBundles.append(ConferenceDescription.ChannelBundle(
                id: bundleId,
                transport: ConferenceDescription.Transport(
                    candidates: [],
                    fingerprints: [],
                    ufrag: "",
                    pwd: ""
                )
            ))
            
            var payload = conference.outgoingColibriDescription()
            if var contents = payload["contents"] as? [[String: Any]] {
                for contentIndex in 0 ..< contents.count {
                    if var channels = contents[contentIndex]["channels"] as? [Any] {
                        for i in (0 ..< channels.count).reversed() {
                            if var channel = channels[i] as? [String: Any] {
                                if channel["endpoint"] as? String != bundleId {
                                    channel = ["id": channel["id"]!]
                                    channels[i] = channel
                                    channels.remove(at: i)
                                }
                            }
                        }
                        contents[contentIndex]["channels"] = channels
                    }
                }
                payload["contents"] = contents
            }
            
            self.disposable.set((httpJsonRequest(url: "http://\(self.colibriHost):8080/colibri/conferences/\(conference.id)", method: .patch(payload), resultType: [String: Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                guard let conference = ConferenceDescription(json: result) else {
                    return
                }
                
                var maybeTransport: ConferenceDescription.Transport?
                for channelBundle in conference.channelBundles {
                    if channelBundle.id == bundleId {
                        maybeTransport = channelBundle.transport
                        break
                    }
                }
                
                guard let transport = maybeTransport else {
                    assert(false)
                    return
                }
                
                guard let (offerSdp, updatedOrder) = conference.offerSdp(sessionId: strongSelf.sessionId, bundleId: bundleId, bridgeHost: strongSelf.colibriHost, transport: transport, currentSsrcOrder: strongSelf.currentSsrcOrder) else {
                    return
                }
                strongSelf.currentSsrcOrder = updatedOrder
                
                strongSelf.conferenceId = conference.id
                strongSelf.localBundleId = bundleId
                strongSelf.localTransport = transport
                
                strongSelf.context.setOfferSdp(offerSdp)
            }))
        }
        
        private func relaySdpAnswer(sdpAnswer: String) {
            guard let conferenceId = self.conferenceId, let localBundleId = self.localBundleId else {
                return
            }
            
            self.disposable.set((httpJsonRequest(url: "http://\(self.colibriHost):8080/colibri/conferences/\(conferenceId)", method: .get, resultType: [String: Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                guard var conference = ConferenceDescription(json: result) else {
                    return
                }
                
                conference.updateLocalChannelFromSdpAnswer(bundleId: localBundleId, sdpAnswer: sdpAnswer)
                
                var payload = conference.outgoingColibriDescription()
                if var contents = payload["contents"] as? [[String: Any]] {
                    for contentIndex in 0 ..< contents.count {
                        if var channels = contents[contentIndex]["channels"] as? [Any] {
                            for i in (0 ..< channels.count).reversed() {
                                if var channel = channels[i] as? [String: Any] {
                                    if channel["endpoint"] as? String != localBundleId {
                                        channel = ["id": channel["id"]!]
                                        channels[i] = channel
                                        channels.remove(at: i)
                                    }
                                }
                            }
                            contents[contentIndex]["channels"] = channels
                        }
                    }
                    payload["contents"] = contents
                }
                
                strongSelf.disposable.set((httpJsonRequest(url: "http://\(strongSelf.colibriHost):8080/colibri/conferences/\(conference.id)", method: .patch(payload), resultType: [String: Any].self)
                |> deliverOn(strongSelf.queue)).start(next: { result in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    guard let conference = ConferenceDescription(json: result) else {
                        return
                    }
                    
                    if conference.id == strongSelf.conferenceId {
                        strongSelf.pollOnceDelayed()
                    }
                }))
            }))
        }
        
        private func pollOnceDelayed() {
            guard let conferenceId = self.conferenceId, let localBundleId = self.localBundleId, let localTransport = self.localTransport else {
                return
            }
            self.pollDisposable.set((httpJsonRequest(url: "http://\(self.colibriHost):8080/colibri/conferences/\(conferenceId)", method: .get, resultType: [String: Any].self)
            |> delay(1.0, queue: self.queue)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                guard let conference = ConferenceDescription(json: result) else {
                    return
                }
                
                guard conference.id == strongSelf.conferenceId else {
                    return
                }
                
                if let (offerSdp, updatedOrder) = conference.offerSdp(sessionId: strongSelf.sessionId, bundleId: localBundleId, bridgeHost: strongSelf.colibriHost, transport: localTransport, currentSsrcOrder: strongSelf.currentSsrcOrder) {
                    strongSelf.currentSsrcOrder = updatedOrder
                    strongSelf.context.setOfferSdp(offerSdp)
                }
                
                strongSelf.pollOnceDelayed()
            }))
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public init(audioSessionActive: Signal<Bool, NoError>) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, audioSessionActive: audioSessionActive)
        })
    }
}
