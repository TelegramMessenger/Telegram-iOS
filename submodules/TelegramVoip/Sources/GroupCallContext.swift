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

private func convertSDPToColibri(conferenceId: String, audioChannelId: String, audioChannelExpire: Int, audioChannelEndpoint: String, audioChannelDirection: String, string: String) -> [String: Any]? {
    let lines = string.components(separatedBy: "\n")
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
    
    var result: [String: Any] = [:]
    
    result["id"] = conferenceId
    
    var contents: [Any] = []
    
    var audio: [String: Any] = [:]
    audio["name"] = "audio"
    
    var audioChannel: [String: Any] = [:]
    audioChannel["id"] = audioChannelId
    audioChannel["expire"] = audioChannelExpire
    audioChannel["endpoint"] = audioChannelEndpoint
    audioChannel["direction"] = audioChannelDirection
    audioChannel["channel-bundle-id"] = audioChannelEndpoint
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
    audioChannel["sources"] = audioSources
    let ssrcGroup = [
        "semantics": "SIM",
        "sources": audioSources
    ] as [String: Any]
    audioChannel["ssrc-groups"] = [ssrcGroup]
    audioChannel["rtp-level-relay-type"] = "translator"
    
    audioChannel["payload-types"] = [
        [
            "id": 111,
            "name": "opus",
            "clockrate": 48000,
            "channels": 2,
            "parameters": [
                "fmtp": [
                    "minptime=10;useinbandfec=1"
                ] as [Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "id": 103,
            "name": "ISAC",
            "clockrate": 16000,
            "channels": 1
        ] as [String: Any],
        [
            "id": 104,
            "name": "ISAC",
            "clockrate": 32000,
            "channels": 1
        ] as [String: Any],
        [
            "id": 126,
            "name": "telephone-event",
            "clockrate": 8000,
            "channels": 1
        ] as [String: Any],
    ] as Any
    
    audioChannel["rtp-hdrexts"] = [
        [
            "id": 1,
            "uri": "urn:ietf:params:rtp-hdrext:ssrc-audio-level"
        ] as [String: Any],
        [
            "id": 3,
            "uri": "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time"
        ] as [String: Any]
    ] as [Any]
    
    guard let ufrag = getLines(prefix: "a=ice-ufrag:").first else {
        return nil
    }
    guard let pwd = getLines(prefix: "a=ice-pwd:").first else {
        return nil
    }
    
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
    
    /*audioChannel["transport"] = [
        "xmlns": "urn:xmpp:jingle:transports:ice-udp:1",
        "rtcp-mux": true,
        "pwd": pwd,
        "ufrag": ufrag,
        "fingerprints": fingerprints,
        "candidates": [
        ] as [Any]
    ] as [String: Any]*/
    
    
    audio["channels"] = [audioChannel]
    contents.append(audio)
    
    result["contents"] = contents
    
    result["channel-bundles"] = [
        [
            "id": audioChannelEndpoint,
            "transport": [
                "candidates": [
                
                ] as [Any],
                "fingerprints": fingerprints,
                "pwd": pwd,
                "ufrag": ufrag,
                "xmlns": "urn:xmpp:jingle:transports:ice-udp:1",
                "rtcp-mux": true
            ] as [String: Any]
        ] as [String: Any]
    ] as [Any]
    
    return result
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
            
            print("PATCH: \(String(data: body, encoding: .utf8)!)")
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
        enum State {
            case empty
            case requestingConference
            case allocatingChannels(conferenceId: String)
        }
        
        private let queue: Queue
        private let context: GroupCallThreadLocalContext
        private let disposable = MetaDisposable()
        
        private var conferenceId: String?
        private var audioChannelId: String?
        private var audioChannelExpire: Int?
        private var audioChannelEndpoint: String?
        private var audioChannelDirection: String?
        
        init(queue: Queue) {
            self.queue = queue
            
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
            
            self.requestConference()
        }
        
        deinit {
            self.disposable.dispose()
        }
        
        func requestConference() {
            self.disposable.set((httpJsonRequest(url: "http://localhost:8080/colibri/conferences/", method: .get, resultType: [Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                if let conference = result.first as? [String: Any], let conferenceId = conference["id"] as? String {
                    strongSelf.allocateChannels(conferenceId: conferenceId)
                } else {
                    strongSelf.disposable.set((httpJsonRequest(url: "http://localhost:8080/colibri/conferences/", method: .post([:]), resultType: [String: Any].self)
                    |> deliverOn(strongSelf.queue)).start(next: { result in
                        guard let strongSelf = self else {
                            return
                        }
                        guard let conferenceId = result["id"] as? String else {
                            return
                        }
                        strongSelf.allocateChannels(conferenceId: conferenceId)
                    }))
                }
            }))
        }
        
        func allocateChannels(conferenceId: String) {
            let bundleId = UUID().uuidString
            
            let audioChannelEndpoint = bundleId
            let audioChannelExpire = 30
            let audioChannelDirection = "sendrecv"
            
            let payload: [String: Any] = [
                "id": conferenceId,
                "contents": [
                    [
                        "name": "audio",
                        "channels": [
                            [
                                "expire": audioChannelExpire,
                                "initiator": true,
                                "endpoint": audioChannelEndpoint,
                                "direction": audioChannelDirection,
                                "channel-bundle-id": audioChannelEndpoint,
                                "rtp-level-relay-type": "mixer"
                            ] as [String: Any]
                        ] as [Any]
                    ] as [String: Any]
                ] as [Any],
                "channel-bundles": [
                    [
                        "id": "\(bundleId)",
                        "transport": [
                            "xmlns": "urn:xmpp:jingle:transports:ice-udp:1",
                            "rtcp-mux": true
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [Any]
            ]
            
            self.disposable.set((httpJsonRequest(url: "http://localhost:8080/colibri/conferences/\(conferenceId)", method: .patch(payload), resultType: [String: Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                guard let channelBundles = result["channel-bundles"] as? [Any] else {
                    return
                }
                guard let channelBundle = channelBundles.first as? [String: Any] else {
                    return
                }
                guard let transport = channelBundle["transport"] as? [String: Any] else {
                    return
                }
                guard let contents = result["contents"] as? [Any] else {
                    return
                }
                
                var audioChannelId: String?
                for item in contents {
                    guard let item = item as? [String: Any] else {
                        continue
                    }
                    guard let channels = item["channels"] as? [Any] else {
                        continue
                    }
                    for channel in channels {
                        if let channel = channel as? [String: Any] {
                            if let id = channel["id"] as? String {
                                audioChannelId = id
                            }
                        }
                    }
                }
                
                let uniqueId = Int(Date().timeIntervalSince1970)
                
                var sdp = ""
                func appendSdp(_ string: String) {
                    if !sdp.isEmpty {
                        sdp.append("\n")
                    }
                    sdp.append(string)
                }
                
                appendSdp("v=0")
                appendSdp("o=- \(uniqueId) 2 IN IP4 0.0.0.0")
                appendSdp("s=-")
                appendSdp("t=0 0")
                appendSdp("a=group:BUNDLE audio")
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
                appendSdp("a=setup:actpass")
                appendSdp("a=mid:audio")
                appendSdp("a=sendrecv")
                
                guard let ufrag = transport["ufrag"] as? String else {
                    return
                }
                guard let pwd = transport["pwd"] as? String else {
                    return
                }
                
                appendSdp("a=ice-ufrag:\(ufrag)")
                appendSdp("a=ice-pwd:\(pwd)")
                
                if let fingerprints = transport["fingerprints"] as? [Any] {
                    for fingerprint in fingerprints {
                        if let fingerprint = fingerprint as? [String: Any] {
                            guard let fingerprintValue = fingerprint["fingerprint"] as? String else {
                                continue
                            }
                            guard let hashMethod = fingerprint["hash"] as? String else {
                                continue
                            }
                            appendSdp("a=fingerprint:\(hashMethod) \(fingerprintValue)")
                        }
                    }
                }
                
                if let candidates = transport["candidates"] as? [Any] {
                    for candidate in candidates {
                        if let candidate = candidate as? [String: Any] {
                            var candidateString = "a=candidate:"
                            guard let foundation = candidate["foundation"] as? String else {
                                continue
                            }
                            candidateString.append("\(foundation) ")
                            guard let component = candidate["component"] as? String else {
                                continue
                            }
                            candidateString.append("\(component) ")
                            guard var protocolValue = candidate["protocol"] as? String else {
                                continue
                            }
                            if protocolValue == "ssltcp" {
                                protocolValue = "tcp"
                            }
                            candidateString.append("\(protocolValue) ")
                            
                            guard let priority = candidate["priority"] as? String else {
                                continue
                            }
                            candidateString.append("\(priority) ")
                            
                            guard let ip = candidate["ip"] as? String else {
                                continue
                            }
                            //candidateString.append("\(ip) ")
                            candidateString.append("127.0.0.1 ")
                            
                            guard let port = candidate["port"] as? String else {
                                continue
                            }
                            candidateString.append("\(port) ")
                            
                            guard let type = candidate["type"] as? String else {
                                continue
                            }
                            candidateString.append("typ \(type) ")
                            
                            switch type {
                            case "srflx", "prflx", "relay":
                                if let relAddr = candidate["rel-addr"] as? String, let relPort = candidate["rel-port"] as? String {
                                    candidateString.append("raddr \(relAddr) rport \(relPort) ")
                                }
                                break
                            default:
                                break
                            }
                            
                            if protocolValue == "tcp" {
                                guard let tcpType = candidate["tcptype"] as? String else {
                                    continue
                                }
                                candidateString.append("tcptype \(tcpType) ")
                            }
                            
                            candidateString.append("generation ")
                            if let generation = candidate["generation"] as? String {
                                candidateString.append(generation)
                            } else {
                                candidateString.append("0")
                            }
                            
                            appendSdp(candidateString)
                        }
                    }
                }
                
                appendSdp("a=rtcp-mux")
                appendSdp("")
                
                strongSelf.conferenceId = conferenceId
                strongSelf.audioChannelId = audioChannelId
                strongSelf.audioChannelExpire = audioChannelExpire
                strongSelf.audioChannelEndpoint = audioChannelEndpoint
                strongSelf.audioChannelDirection = audioChannelDirection
                
                strongSelf.context.setOfferSdp(sdp)
            }))
        }
        
        private func relaySdpAnswer(sdpAnswer: String) {
            guard let payload = convertSDPToColibri(
                conferenceId: conferenceId!,
                audioChannelId: audioChannelId!,
                audioChannelExpire: audioChannelExpire!,
                audioChannelEndpoint: audioChannelEndpoint!,
                audioChannelDirection: audioChannelDirection!,
                string: sdpAnswer
            ) else {
                return
            }
            self.disposable.set((httpJsonRequest(url: "http://localhost:8080/colibri/conferences/\(conferenceId!)", method: .patch(payload), resultType: [String: Any].self)
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
            }))
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
}
