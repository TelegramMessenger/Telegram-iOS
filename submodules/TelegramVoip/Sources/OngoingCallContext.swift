import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import Network

import TgVoip
import TgVoipWebrtc

private let debugUseLegacyVersionForReflectors: Bool = {
    #if DEBUG && false
    return true
    #else
    return false
    #endif
}()

private struct PeerTag: Hashable, CustomStringConvertible {
    var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 16)
    
    var canonical: PeerTag {
        var updatedBytes = self.bytes
        updatedBytes[0] &= ~1
        return PeerTag(bytes: updatedBytes)
    }
    
    var flipped: PeerTag {
        var updatedBytes = self.bytes
        updatedBytes[0] ^= 1
        return PeerTag(bytes: updatedBytes)
    }
    
    var description: String {
        var result = ""
        
        for byte in bytes {
            result.append(String(byte, radix: 16))
        }
        
        return result
    }
}

private extension PeerTag {
    init(data: Data) {
        precondition(data.count >= 16)
        data.withUnsafeBytes { buffer -> Void in
            memcpy(&self.bytes, buffer.baseAddress!.assumingMemoryBound(to: UInt8.self), 16)
        }
    }
    
    var data: Data {
        var bytes = self.bytes
        var resultData = Data(repeating: 0, count: 16)
        resultData.withUnsafeMutableBytes { buffer -> Void in
            memcpy(buffer.baseAddress!.assumingMemoryBound(to: UInt8.self), &bytes, 16)
        }
        return resultData
    }
}

private func flippedPeerTag(_ data: Data) -> Data {
    return PeerTag(data: data).flipped.data
}

private func callConnectionDescription(_ connection: CallSessionConnection) -> OngoingCallConnectionDescription? {
    switch connection {
    case let .reflector(reflector):
        return OngoingCallConnectionDescription(connectionId: reflector.id, ip: reflector.ip, ipv6: reflector.ipv6, port: reflector.port, peerTag: reflector.peerTag)
    case .webRtcReflector:
        return nil
    }
}

private func callConnectionDescriptionsWebrtc(_ connection: CallSessionConnection, idMapping: [Int64: UInt8]) -> [OngoingCallConnectionDescriptionWebrtc] {
    switch connection {
    case let .reflector(reflector):
        guard let id = idMapping[reflector.id] else {
            return []
        }
        var result: [OngoingCallConnectionDescriptionWebrtc] = []
        if !reflector.ip.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(reflectorId: id, hasStun: false, hasTurn: true, hasTcp: reflector.isTcp, ip: reflector.ip, port: reflector.port, username: "reflector", password: hexString(reflector.peerTag)))
        }
        if !reflector.ipv6.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(reflectorId: id, hasStun: false, hasTurn: true, hasTcp: reflector.isTcp, ip: reflector.ipv6, port: reflector.port, username: "reflector", password: hexString(reflector.peerTag)))
        }
        return result
    case let .webRtcReflector(reflector):
        var result: [OngoingCallConnectionDescriptionWebrtc] = []
        if !reflector.ip.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(reflectorId: 0, hasStun: reflector.hasStun, hasTurn: reflector.hasTurn, hasTcp: false, ip: reflector.ip, port: reflector.port, username: reflector.username, password: reflector.password))
        }
        if !reflector.ipv6.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(reflectorId: 0, hasStun: reflector.hasStun, hasTurn: reflector.hasTurn, hasTcp: false, ip: reflector.ipv6, port: reflector.port, username: reflector.username, password: reflector.password))
        }
        return result
    }
}

public func callLogNameForId(id: Int64, account: Account) -> String? {
    let path = callLogsPath(account: account)
    let namePrefix = "\(id)_"
    
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if url.lastPathComponent.hasPrefix(namePrefix) {
                    if url.lastPathComponent.hasSuffix(".log.json") {
                        continue
                    }
                    return url.lastPathComponent
                }
            }
        }
    }
    return nil
}

public func callLogsPath(account: Account) -> String {
    return account.basePath + "/calls"
}

private func cleanupCallLogs(account: Account) {
    let path = callLogsPath(account: account)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path, isDirectory: nil) {
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    var oldest: [(URL, Date)] = []
    var count = 0
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if let date = (try? url.resourceValues(forKeys: Set([.contentModificationDateKey])))?.contentModificationDate {
                    oldest.append((url, date))
                    count += 1
                }
            }
        }
    }
    let callLogsLimit = 40
    if count > callLogsLimit {
        oldest.sort(by: { $0.1 > $1.1 })
        while oldest.count > callLogsLimit {
            try? fileManager.removeItem(atPath: oldest[oldest.count - 1].0.path)
            oldest.removeLast()
        }
    }
}

private let setupLogs: Bool = {
    OngoingCallThreadLocalContext.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })
    OngoingCallThreadLocalContextWebrtc.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })
    return true
}()

public struct OngoingCallContextState: Equatable {
    public enum State {
        case initializing
        case connected
        case reconnecting
        case failed
    }
    
    public enum VideoState: Equatable {
        case notAvailable
        case inactive
        case active
        case paused
    }
    
    public enum RemoteVideoState: Equatable {
        case inactive
        case active
        case paused
    }
    
    public enum RemoteAudioState: Equatable {
        case active
        case muted
    }
    
    public enum RemoteBatteryLevel: Equatable {
        case normal
        case low
    }
    
    public let state: State
    public let videoState: VideoState
    public let remoteVideoState: RemoteVideoState
    public let remoteAudioState: RemoteAudioState
    public let remoteBatteryLevel: RemoteBatteryLevel
}

private final class OngoingCallThreadLocalContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueue, OngoingCallThreadLocalContextQueueWebrtc /*, OngoingCallThreadLocalContextQueueWebrtcCustom*/ {
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

private func ongoingNetworkTypeForType(_ type: NetworkType) -> OngoingCallNetworkType {
    switch type {
        case .none:
            return .wifi
        case .wifi:
            return .wifi
        case let .cellular(cellular):
            switch cellular {
                case .edge:
                    return .cellularEdge
                case .gprs:
                    return .cellularGprs
                case .thirdG, .unknown:
                    return .cellular3g
                case .lte:
                    return .cellularLte
            }
    }
}

private func ongoingNetworkTypeForTypeWebrtc(_ type: NetworkType) -> OngoingCallNetworkTypeWebrtc {
    switch type {
        case .none:
            return .wifi
        case .wifi:
            return .wifi
        case let .cellular(cellular):
            switch cellular {
                case .edge:
                    return .cellularEdge
                case .gprs:
                    return .cellularGprs
                case .thirdG, .unknown:
                    return .cellular3g
                case .lte:
                    return .cellularLte
            }
    }
}

/*private func ongoingNetworkTypeForTypeWebrtcCustom(_ type: NetworkType) -> OngoingCallNetworkTypeWebrtcCustom {
    switch type {
        case .none:
            return .wifi
        case .wifi:
            return .wifi
        case let .cellular(cellular):
            switch cellular {
                case .edge:
                    return .cellularEdge
                case .gprs:
                    return .cellularGprs
                case .thirdG, .unknown:
                    return .cellular3g
                case .lte:
                    return .cellularLte
            }
    }
}*/

private func ongoingDataSavingForType(_ type: VoiceCallDataSaving) -> OngoingCallDataSaving {
    switch type {
        case .never:
            return .never
        case .cellular:
            return .cellular
        case .always:
            return .always
        default:
            return .never
    }
}

private func ongoingDataSavingForTypeWebrtc(_ type: VoiceCallDataSaving) -> OngoingCallDataSavingWebrtc {
    switch type {
        case .never:
            return .never
        case .cellular:
            return .cellular
        case .always:
            return .always
        default:
            return .never
    }
}

private protocol OngoingCallThreadLocalContextProtocol: AnyObject {
    func nativeSetNetworkType(_ type: NetworkType)
    func nativeSetIsMuted(_ value: Bool)
    func nativeSetIsLowBatteryLevel(_ value: Bool)
    func nativeRequestVideo(_ capturer: OngoingCallVideoCapturer)
    func nativeSetRequestedVideoAspect(_ aspect: Float)
    func nativeDisableVideo()
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void)
    func nativeBeginTermination()
    func nativeDebugInfo() -> String
    func nativeVersion() -> String
    func nativeGetDerivedState() -> Data
    func addExternalAudioData(data: Data)
}

private final class OngoingCallThreadLocalContextHolder {
    let context: OngoingCallThreadLocalContextProtocol
    
    init(_ context: OngoingCallThreadLocalContextProtocol) {
        self.context = context
    }
}

extension OngoingCallThreadLocalContext: OngoingCallThreadLocalContextProtocol {
    func nativeSetNetworkType(_ type: NetworkType) {
        self.setNetworkType(ongoingNetworkTypeForType(type))
    }
    
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void) {
        self.stop(completion)
    }
    
    func nativeBeginTermination() {
    }
    
    func nativeSetIsMuted(_ value: Bool) {
        self.setIsMuted(value)
    }
    
    func nativeSetIsLowBatteryLevel(_ value: Bool) {
    }
    
    func nativeRequestVideo(_ capturer: OngoingCallVideoCapturer) {
    }
    
    func nativeSetRequestedVideoAspect(_ aspect: Float) {
    }
    
    func nativeDisableVideo() {
    }
    
    func nativeSwitchVideoCamera() {
    }
    
    func nativeDebugInfo() -> String {
        return self.debugInfo() ?? ""
    }
    
    func nativeVersion() -> String {
        return self.version() ?? ""
    }
    
    func nativeGetDerivedState() -> Data {
        return self.getDerivedState()
    }

    func addExternalAudioData(data: Data) {
    }
}

public final class OngoingCallVideoCapturer {
    internal let impl: OngoingCallThreadLocalContextVideoCapturer

    private let isActivePromise = ValuePromise<Bool>(true, ignoreRepeated: true)
    public var isActive: Signal<Bool, NoError> {
        return self.isActivePromise.get()
    }
    
    public init(keepLandscape: Bool = false, isCustom: Bool = false) {
        if isCustom {
            self.impl = OngoingCallThreadLocalContextVideoCapturer.withExternalSampleBufferProvider()
        } else {
            self.impl = OngoingCallThreadLocalContextVideoCapturer(deviceId: "", keepLandscape: keepLandscape)
        }
        let isActivePromise = self.isActivePromise
        self.impl.setOnIsActiveUpdated({ value in
            isActivePromise.set(value)
        })
    }
    
    public func switchVideoInput(isFront: Bool) {
        self.impl.switchVideoInput(isFront ? "" : "back")
    }
    
    public func makeOutgoingVideoView(requestClone: Bool, completion: @escaping (OngoingCallContextPresentationCallVideoView?, OngoingCallContextPresentationCallVideoView?) -> Void) {
        self.impl.makeOutgoingVideoView(requestClone, completion: { mainView, cloneView in
            if let mainView = mainView {
                let mainVideoView = OngoingCallContextPresentationCallVideoView(
                    view: mainView,
                    setOnFirstFrameReceived: { [weak mainView] f in
                        mainView?.setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak mainView] in
                        if let mainView = mainView {
                            return OngoingCallVideoOrientation(mainView.orientation)
                        } else {
                            return .rotation0
                        }
                    },
                    getAspect: { [weak mainView] in
                        if let mainView = mainView {
                            return mainView.aspect
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { [weak mainView] f in
                        mainView?.setOnOrientationUpdated { value, aspect in
                            f?(OngoingCallVideoOrientation(value), aspect)
                        }
                    },
                    setOnIsMirroredUpdated: { [weak mainView] f in
                        mainView?.setOnIsMirroredUpdated(f)
                    },
                    updateIsEnabled: { [weak mainView] value in
                        mainView?.updateIsEnabled(value)
                    }
                )
                var cloneVideoView: OngoingCallContextPresentationCallVideoView?
                if let cloneView = cloneView {
                    cloneVideoView = OngoingCallContextPresentationCallVideoView(
                        view: cloneView,
                        setOnFirstFrameReceived: { [weak cloneView] f in
                            cloneView?.setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak cloneView] in
                            if let cloneView = cloneView {
                                return OngoingCallVideoOrientation(cloneView.orientation)
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak cloneView] in
                            if let cloneView = cloneView {
                                return cloneView.aspect
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { [weak cloneView] f in
                            cloneView?.setOnOrientationUpdated { value, aspect in
                                f?(OngoingCallVideoOrientation(value), aspect)
                            }
                        },
                        setOnIsMirroredUpdated: { [weak cloneView] f in
                            cloneView?.setOnIsMirroredUpdated(f)
                        },
                        updateIsEnabled: { [weak cloneView] value in
                            cloneView?.updateIsEnabled(value)
                        }
                    )
                }
                completion(mainVideoView, cloneVideoView)
            } else {
                completion(nil, nil)
            }
        })
    }
    
    public func setIsVideoEnabled(_ value: Bool) {
        self.impl.setIsVideoEnabled(value)
    }

    public func injectPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: CGImagePropertyOrientation) {
        var videoRotation: OngoingCallVideoOrientation = .rotation0
        switch rotation {
            case .up:
                videoRotation = .rotation0
            case .left:
                videoRotation = .rotation90
            case .right:
                videoRotation = .rotation270
            case .down:
                videoRotation = .rotation180
            default:
                videoRotation = .rotation0
        }
        self.impl.submitPixelBuffer(pixelBuffer, rotation: videoRotation.orientation)
    }

    public func video() -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        let queue = Queue.mainQueue()
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()

            queue.async {
                guard let strongSelf = self else {
                    return
                }
                let innerDisposable = strongSelf.impl.addVideoOutput { videoFrameData in
                    subscriber.putNext(OngoingGroupCallContext.VideoFrameData(frameData: videoFrameData))
                }
                disposable.set(ActionDisposable {
                    innerDisposable.dispose()
                })
            }

            return disposable
        }
    }
}

extension OngoingCallThreadLocalContextWebrtc: OngoingCallThreadLocalContextProtocol {
    func nativeSetNetworkType(_ type: NetworkType) {
        self.setNetworkType(ongoingNetworkTypeForTypeWebrtc(type))
    }
    
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void) {
        self.stop(completion)
    }
    
    func nativeBeginTermination() {
        self.beginTermination()
    }
    
    func nativeSetIsMuted(_ value: Bool) {
        self.setIsMuted(value)
    }
    
    func nativeSetIsLowBatteryLevel(_ value: Bool) {
        self.setIsLowBatteryLevel(value)
    }
    
    func nativeRequestVideo(_ capturer: OngoingCallVideoCapturer) {
        self.requestVideo(capturer.impl)
    }
    
    func nativeSetRequestedVideoAspect(_ aspect: Float) {
        self.setRequestedVideoAspect(aspect)
    }
    
    func nativeDisableVideo() {
        self.disableVideo()
    }
    
    func nativeDebugInfo() -> String {
        return self.debugInfo() ?? ""
    }
    
    func nativeVersion() -> String {
        return self.version() ?? ""
    }
    
    func nativeGetDerivedState() -> Data {
        return self.getDerivedState()
    }

    func addExternalAudioData(data: Data) {
        self.addExternalAudioData(data)
    }
}

private extension OngoingCallContextState.State {
    init(_ state: OngoingCallState) {
        switch state {
        case .initializing:
            self = .initializing
        case .connected:
            self = .connected
        case .failed:
            self = .failed
        case .reconnecting:
            self = .reconnecting
        default:
            self = .failed
        }
    }
}

private extension OngoingCallContextState.State {
    init(_ state: OngoingCallStateWebrtc) {
        switch state {
        case .initializing:
            self = .initializing
        case .connected:
            self = .connected
        case .failed:
            self = .failed
        case .reconnecting:
            self = .reconnecting
        default:
            self = .failed
        }
    }
}

public enum OngoingCallVideoOrientation {
    case rotation0
    case rotation90
    case rotation180
    case rotation270
}

extension OngoingCallVideoOrientation {
    init(_ orientation: OngoingCallVideoOrientationWebrtc) {
        switch orientation {
        case .orientation0:
            self = .rotation0
        case .orientation90:
            self = .rotation90
        case .orientation180:
            self = .rotation180
        case .orientation270:
            self = .rotation270
        @unknown default:
            self = .rotation0
        }
    }
    
    var orientation: OngoingCallVideoOrientationWebrtc {
        switch self {
        case .rotation0:
            return .orientation0
        case .rotation90:
            return .orientation90
        case .rotation180:
            return .orientation180
        case  .rotation270:
            return .orientation270
        }
    }
}

public final class OngoingCallContextPresentationCallVideoView {
    public let view: UIView
    public let setOnFirstFrameReceived: (((Float) -> Void)?) -> Void
    public let getOrientation: () -> OngoingCallVideoOrientation
    public let getAspect: () -> CGFloat
    public let setOnOrientationUpdated: (((OngoingCallVideoOrientation, CGFloat) -> Void)?) -> Void
    public let setOnIsMirroredUpdated: (((Bool) -> Void)?) -> Void
    public let updateIsEnabled: (Bool) -> Void
    
    public init(
        view: UIView,
        setOnFirstFrameReceived: @escaping (((Float) -> Void)?) -> Void,
        getOrientation: @escaping () -> OngoingCallVideoOrientation,
        getAspect: @escaping () -> CGFloat,
        setOnOrientationUpdated: @escaping (((OngoingCallVideoOrientation, CGFloat) -> Void)?) -> Void,
        setOnIsMirroredUpdated: @escaping (((Bool) -> Void)?) -> Void,
        updateIsEnabled: @escaping (Bool) -> Void
    ) {
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
        self.getOrientation = getOrientation
        self.getAspect = getAspect
        self.setOnOrientationUpdated = setOnOrientationUpdated
        self.setOnIsMirroredUpdated = setOnIsMirroredUpdated
        self.updateIsEnabled = updateIsEnabled
    }
}

public final class OngoingCallContext {
    public struct AuxiliaryServer {
        public enum Connection {
            case stun
            case turn(username: String, password: String)
        }
        
        public let host: String
        public let port: Int
        public let connection: Connection
        
        public init(
            host: String,
            port: Int,
            connection: Connection
        ) {
            self.host = host
            self.port = port
            self.connection = connection
        }
    }
    
    public let callId: CallId
    public let internalId: CallSessionInternalId
    
    private let queue = Queue()
    private let account: Account
    private let callSessionManager: CallSessionManager
    private let logPath: String
    
    private var contextRef: Unmanaged<OngoingCallThreadLocalContextHolder>?
    
    private let contextState = Promise<OngoingCallContextState?>(nil)
    public var state: Signal<OngoingCallContextState?, NoError> {
        return self.contextState.get()
    }
    
    private var didReportCallAsVideo: Bool = false
    
    private var signalingDataDisposable: Disposable?
    
    private let receptionPromise = Promise<Int32?>(nil)
    public var reception: Signal<Int32?, NoError> {
        return self.receptionPromise.get()
    }
    
    private let audioLevelPromise = Promise<Float>(0.0)
    public var audioLevel: Signal<Float, NoError> {
        return self.audioLevelPromise.get()
    }
    
    private let audioSessionDisposable = MetaDisposable()
    private var networkTypeDisposable: Disposable?
    
    public static var maxLayer: Int32 {
        return OngoingCallThreadLocalContext.maxLayer()
    }
    
    private let tempLogFile: EngineTempBoxFile
    private let tempStatsLogFile: EngineTempBoxFile
    
    private var signalingConnectionManager: QueueLocalObject<CallSignalingConnectionManager>?
    
    public static func versions(includeExperimental: Bool, includeReference: Bool) -> [(version: String, supportsVideo: Bool)] {
        #if os(iOS) && DEBUG && false
        if "".isEmpty {
            return [("5.0.0", true)]
        }
        #endif
        
        if debugUseLegacyVersionForReflectors {
            return [(OngoingCallThreadLocalContext.version(), true)]
        } else {
            var result: [(version: String, supportsVideo: Bool)] = [(OngoingCallThreadLocalContext.version(), false)]
            result.append(contentsOf: OngoingCallThreadLocalContextWebrtc.versions(withIncludeReference: includeReference).map { version -> (version: String, supportsVideo: Bool) in
                return (version, true)
            })
            return result
        }
    }

    public init(account: Account, callSessionManager: CallSessionManager, callId: CallId, internalId: CallSessionInternalId, proxyServer: ProxyServerSettings?, initialNetworkType: NetworkType, updatedNetworkType: Signal<NetworkType, NoError>, serializedData: String?, dataSaving: VoiceCallDataSaving, key: Data, isOutgoing: Bool, video: OngoingCallVideoCapturer?, connections: CallSessionConnectionSet, maxLayer: Int32, version: String, allowP2P: Bool, enableTCP: Bool, enableStunMarking: Bool, audioSessionActive: Signal<Bool, NoError>, logName: String, preferredVideoCodec: String?) {
        let _ = setupLogs
        OngoingCallThreadLocalContext.applyServerConfig(serializedData)
        
        self.callId = callId
        self.internalId = internalId
        self.account = account
        self.callSessionManager = callSessionManager
        self.logPath = logName.isEmpty ? "" : callLogsPath(account: self.account) + "/" + logName + ".log"
        let logPath = self.logPath
        self.tempLogFile = EngineTempBox.shared.tempFile(fileName: "CallLog.txt")
        let tempLogPath = self.tempLogFile.path
        
        self.tempStatsLogFile = EngineTempBox.shared.tempFile(fileName: "CallStats.json")
        let tempStatsLogPath = self.tempStatsLogFile.path
        
        let queue = self.queue
        
        cleanupCallLogs(account: account)
        
        self.audioSessionDisposable.set((audioSessionActive
        |> filter { $0 }
        |> take(1)
        |> deliverOn(queue)).start(next: { [weak self] _ in
            if let strongSelf = self {
                var useModernImplementation = true
                var version = version
                var allowP2P = allowP2P
                if debugUseLegacyVersionForReflectors {
                    useModernImplementation = true
                    version = "5.0.0"
                    allowP2P = false
                } else {
                    useModernImplementation = version != OngoingCallThreadLocalContext.version()
                }
                
                if useModernImplementation {
                    var voipProxyServer: VoipProxyServerWebrtc?
                    if let proxyServer = proxyServer {
                        switch proxyServer.connection {
                        case let .socks5(username, password):
                            voipProxyServer = VoipProxyServerWebrtc(host: proxyServer.host, port: proxyServer.port, username: username, password: password)
                        case .mtp:
                            break
                        }
                    }
                    
                    let unfilteredConnections = [connections.primary] + connections.alternatives
                    
                    var reflectorIdList: [Int64] = []
                    for connection in unfilteredConnections {
                        switch connection {
                        case let .reflector(reflector):
                            reflectorIdList.append(reflector.id)
                        case .webRtcReflector:
                            break
                        }
                    }
                    
                    reflectorIdList.sort()
                    
                    var reflectorIdMapping: [Int64: UInt8] = [:]
                    for i in 0 ..< reflectorIdList.count {
                        reflectorIdMapping[reflectorIdList[i]] = UInt8(i + 1)
                    }
                    
                    var signalingReflector: OngoingCallConnectionDescriptionWebrtc?
                    
                    var processedConnections: [CallSessionConnection] = []
                    var filteredConnections: [OngoingCallConnectionDescriptionWebrtc] = []
                    connectionsLoop: for connection in unfilteredConnections {
                        if processedConnections.contains(connection) {
                            continue
                        }
                        processedConnections.append(connection)
                        
                        switch connection {
                        case let .reflector(reflector):
                            if reflector.isTcp {
                                if signalingReflector == nil {
                                    signalingReflector = OngoingCallConnectionDescriptionWebrtc(reflectorId: 0, hasStun: false, hasTurn: true, hasTcp: true, ip: reflector.ip, port: reflector.port, username: "reflector", password: hexString(reflector.peerTag))
                                }
                                
                                continue connectionsLoop
                            }
                        case .webRtcReflector:
                            break
                        }
                        
                        var webrtcConnections: [OngoingCallConnectionDescriptionWebrtc] = []
                        for connection in callConnectionDescriptionsWebrtc(connection, idMapping: reflectorIdMapping) {
                            webrtcConnections.append(connection)
                        }
                        
                        filteredConnections.append(contentsOf: webrtcConnections)
                    }
                    
                    if let signalingReflector = signalingReflector {
                        if #available(iOS 12.0, *) {
                            let peerTag = dataWithHexString(signalingReflector.password)
                            
                            strongSelf.signalingConnectionManager = QueueLocalObject(queue: queue, generate: {
                                return CallSignalingConnectionManager(queue: queue, peerTag: peerTag, servers: [signalingReflector], dataReceived: { data in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.withContext { context in
                                        if let context = context as? OngoingCallThreadLocalContextWebrtc {
                                            context.addSignaling(data)
                                        }
                                    }
                                })
                            })
                        }
                    }
                    
                    let context = OngoingCallThreadLocalContextWebrtc(version: version, queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, networkType: ongoingNetworkTypeForTypeWebrtc(initialNetworkType), dataSaving: ongoingDataSavingForTypeWebrtc(dataSaving), derivedState: Data(), key: key, isOutgoing: isOutgoing, connections: filteredConnections, maxLayer: maxLayer, allowP2P: allowP2P, allowTCP: enableTCP, enableStunMarking: enableStunMarking, logPath: tempLogPath, statsLogPath: tempStatsLogPath, sendSignalingData: { [weak callSessionManager] data in
                        queue.async {
                            guard let strongSelf = self else {
                                return
                            }
                            if let signalingConnectionManager = strongSelf.signalingConnectionManager {
                                signalingConnectionManager.with { impl in
                                    impl.send(payloadData: data)
                                }
                            }
                            
                            if let callSessionManager = callSessionManager {
                                callSessionManager.sendSignalingData(internalId: internalId, data: data)
                            }
                        }
                    }, videoCapturer: video?.impl, preferredVideoCodec: preferredVideoCodec, audioInputDeviceId: "")
                    
                    strongSelf.contextRef = Unmanaged.passRetained(OngoingCallThreadLocalContextHolder(context))
                    context.stateChanged = { [weak callSessionManager] state, videoState, remoteVideoState, remoteAudioState, remoteBatteryLevel, _ in
                        queue.async {
                            guard let strongSelf = self else {
                                return
                            }
                            let mappedState = OngoingCallContextState.State(state)
                            let mappedVideoState: OngoingCallContextState.VideoState
                            switch videoState {
                            case .inactive:
                                mappedVideoState = .inactive
                            case .active:
                                mappedVideoState = .active
                            case .paused:
                                mappedVideoState = .paused
                            @unknown default:
                                mappedVideoState = .notAvailable
                            }
                            let mappedRemoteVideoState: OngoingCallContextState.RemoteVideoState
                            switch remoteVideoState {
                            case .inactive:
                                mappedRemoteVideoState = .inactive
                            case .active:
                                mappedRemoteVideoState = .active
                            case .paused:
                                mappedRemoteVideoState = .paused
                            @unknown default:
                                mappedRemoteVideoState = .inactive
                            }
                            let mappedRemoteAudioState: OngoingCallContextState.RemoteAudioState
                            switch remoteAudioState {
                            case .active:
                                mappedRemoteAudioState = .active
                            case .muted:
                                mappedRemoteAudioState = .muted
                            @unknown default:
                                mappedRemoteAudioState = .active
                            }
                            let mappedRemoteBatteryLevel: OngoingCallContextState.RemoteBatteryLevel
                            switch remoteBatteryLevel {
                            case .normal:
                                mappedRemoteBatteryLevel = .normal
                            case .low:
                                mappedRemoteBatteryLevel = .low
                            @unknown default:
                                mappedRemoteBatteryLevel = .normal
                            }
                            if case .active = mappedVideoState, !strongSelf.didReportCallAsVideo {
                                strongSelf.didReportCallAsVideo = true
                                callSessionManager?.updateCallType(internalId: internalId, type: .video)
                            }
                            strongSelf.contextState.set(.single(OngoingCallContextState(state: mappedState, videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)))
                        }
                    }
                    strongSelf.receptionPromise.set(.single(4))
                    context.signalBarsChanged = { signalBars in
                        self?.receptionPromise.set(.single(signalBars))
                    }
                    context.audioLevelUpdated = { level in
                        self?.audioLevelPromise.set(.single(level))
                    }
                    
                    strongSelf.networkTypeDisposable = (updatedNetworkType
                    |> deliverOn(queue)).start(next: { networkType in
                        self?.withContext { context in
                            context.nativeSetNetworkType(networkType)
                        }
                    })
                } else {
                    var voipProxyServer: VoipProxyServer?
                    if let proxyServer = proxyServer {
                        switch proxyServer.connection {
                        case let .socks5(username, password):
                            voipProxyServer = VoipProxyServer(host: proxyServer.host, port: proxyServer.port, username: username, password: password)
                        case .mtp:
                            break
                        }
                    }
                    let context = OngoingCallThreadLocalContext(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, networkType: ongoingNetworkTypeForType(initialNetworkType), dataSaving: ongoingDataSavingForType(dataSaving), derivedState: Data(), key: key, isOutgoing: isOutgoing, primaryConnection: callConnectionDescription(connections.primary)!, alternativeConnections: connections.alternatives.compactMap(callConnectionDescription), maxLayer: maxLayer, allowP2P: allowP2P, logPath: logPath)
                    
                    strongSelf.contextRef = Unmanaged.passRetained(OngoingCallThreadLocalContextHolder(context))
                    context.stateChanged = { state in
                        self?.contextState.set(.single(OngoingCallContextState(state: OngoingCallContextState.State(state), videoState: .notAvailable, remoteVideoState: .inactive, remoteAudioState: .active, remoteBatteryLevel: .normal)))
                    }
                    context.signalBarsChanged = { signalBars in
                        self?.receptionPromise.set(.single(signalBars))
                    }
                    
                    strongSelf.networkTypeDisposable = (updatedNetworkType
                    |> deliverOn(queue)).start(next: { networkType in
                        self?.withContext { context in
                            context.nativeSetNetworkType(networkType)
                        }
                    })
                }

                strongSelf.signalingDataDisposable = callSessionManager.beginReceivingCallSignalingData(internalId: internalId, { [weak self] dataList in
                    queue.async {
                        self?.withContext { context in
                            if let context = context as? OngoingCallThreadLocalContextWebrtc {
                                for data in dataList {
                                    context.addSignaling(data)
                                }
                            }
                        }
                    }
                })
                
                strongSelf.signalingConnectionManager?.with { impl in
                    impl.start()
                }
            }
        }))
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
        
        self.audioSessionDisposable.dispose()
        self.networkTypeDisposable?.dispose()
    }
        
    private func withContext(_ f: @escaping (OngoingCallThreadLocalContextProtocol) -> Void) {
        self.queue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context.context)
            }
        }
    }
    
    private func withContextThenDeallocate(_ f: @escaping (OngoingCallThreadLocalContextProtocol) -> Void) {
        self.queue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context.context)
                
                self.contextRef?.release()
                self.contextRef = nil
            }
        }
    }
    
    public func beginTermination() {
        self.withContext { context in
            context.nativeBeginTermination()
        }
    }
    
    public func stop(sendDebugLogs: Bool = false, debugLogValue: Promise<String?>) {
        let callId = self.callId
        let account = self.account
        let logPath = self.logPath
        var statsLogPath = ""
        if !logPath.isEmpty {
            statsLogPath = logPath + ".json"
        }
        let tempLogPath = self.tempLogFile.path
        let tempStatsLogPath = self.tempStatsLogFile.path
        
        self.withContextThenDeallocate { context in
            context.nativeStop { debugLog, bytesSentWifi, bytesReceivedWifi, bytesSentMobile, bytesReceivedMobile in
                let delta = NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: bytesReceivedMobile,
                        outgoing: bytesSentMobile),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: bytesReceivedWifi,
                        outgoing: bytesSentWifi))
                updateAccountNetworkUsageStats(account: self.account, category: .call, delta: delta)
                
                if !logPath.isEmpty {
                    let logsPath = callLogsPath(account: account)
                    let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
                    let _ = try? FileManager.default.moveItem(atPath: tempLogPath, toPath: logPath)
                }
                
                if !statsLogPath.isEmpty {
                    let logsPath = callLogsPath(account: account)
                    let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
                    let _ = try? FileManager.default.moveItem(atPath: tempStatsLogPath, toPath: statsLogPath)
                }
                
                if !statsLogPath.isEmpty, let data = try? Data(contentsOf: URL(fileURLWithPath: statsLogPath)), let dataString = String(data: data, encoding: .utf8) {
                    debugLogValue.set(.single(dataString))
                    let engine = TelegramEngine(account: self.account)
                    let _ = engine.calls.saveCallDebugLog(callId: callId, log: dataString).start(next: { result in
                        switch result {
                        case .sendFullLog:
                            if !logPath.isEmpty {
                                let _ = engine.calls.saveCompleteCallDebugLog(callId: callId, logPath: logPath).start()
                            }
                        case .done:
                            break
                        }
                    })
                }
            }
        }
    }
    
    public func setIsMuted(_ value: Bool) {
        self.withContext { context in
            context.nativeSetIsMuted(value)
        }
    }
    
    public func setIsLowBatteryLevel(_ value: Bool) {
        self.withContext { context in
            context.nativeSetIsLowBatteryLevel(value)
        }
    }
    
    public func requestVideo(_ capturer: OngoingCallVideoCapturer) {
        self.withContext { context in
            context.nativeRequestVideo(capturer)
        }
    }
    
    public func setRequestedVideoAspect(_ aspect: Float) {
        self.withContext { context in
            context.nativeSetRequestedVideoAspect(aspect)
        }
    }
    
    public func disableVideo() {
        self.withContext { context in
            context.nativeDisableVideo()
        }
    }
    
    public func debugInfo() -> Signal<(String, String), NoError> {
        let poll = Signal<(String, String), NoError> { subscriber in
            self.withContext { context in
                let version = context.nativeVersion()
                let debugInfo = context.nativeDebugInfo()
                subscriber.putNext((version, debugInfo))
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
        return (poll |> then(.complete() |> delay(0.5, queue: Queue.concurrentDefaultQueue()))) |> restart
    }
    
    public func makeIncomingVideoView(completion: @escaping (OngoingCallContextPresentationCallVideoView?) -> Void) {
        self.withContext { context in
            if let context = context as? OngoingCallThreadLocalContextWebrtc {
                context.makeIncomingVideoView { view in
                    if let view = view {
                        completion(OngoingCallContextPresentationCallVideoView(
                            view: view,
                            setOnFirstFrameReceived: { [weak view] f in
                                view?.setOnFirstFrameReceived(f)
                            },
                            getOrientation: { [weak view] in
                                if let view = view {
                                    return OngoingCallVideoOrientation(view.orientation)
                                } else {
                                    return .rotation0
                                }
                            },
                            getAspect: { [weak view] in
                                if let view = view {
                                    return view.aspect
                                } else {
                                    return 0.0
                                }
                            },
                            setOnOrientationUpdated: { [weak view] f in
                                view?.setOnOrientationUpdated { value, aspect in
                                    f?(OngoingCallVideoOrientation(value), aspect)
                                }
                            },
                            setOnIsMirroredUpdated: { [weak view] f in
                                view?.setOnIsMirroredUpdated { value in
                                    f?(value)
                                }
                            },
                            updateIsEnabled: { [weak view] value in
                                view?.updateIsEnabled(value)
                            }
                        ))
                    } else {
                        completion(nil)
                    }
                }
            } else {
                completion(nil)
            }
        }
    }

    public func addExternalAudioData(data: Data) {
        self.withContext { context in
            context.addExternalAudioData(data: data)
        }
    }
}

private protocol CallSignalingConnection {
    func start()
    func stop()
    func send(payloadData: Data)
}

@available(iOS 12.0, *)
private final class CallSignalingConnectionImpl: CallSignalingConnection {
    private let queue: Queue
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let peerTag: Data
    private let dataReceived: (Data) -> Void
    private let isClosed: () -> Void
    private let connection: NWConnection
    
    private var isConnected: Bool = false
    
    private var pingTimer: SwiftSignalKit.Timer?
    
    private var queuedPayloads: [Data] = []
    
    init(queue: Queue, host: String, port: UInt16, peerTag: Data, dataReceived: @escaping (Data) -> Void, isClosed: @escaping () -> Void) {
        self.queue = queue
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.peerTag = peerTag
        self.dataReceived = dataReceived
        self.isClosed = isClosed
        self.connection = NWConnection(host: self.host, port: self.port, using: .tcp)
        
        self.connection.stateUpdateHandler = { [weak self] state in
            queue.async {
                self?.stateUpdated(state: state)
            }
        }
    }
    
    private func stateUpdated(state: NWConnection.State) {
        switch state {
        case .ready:
            OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection state is ready")
            
            var headerData = Data(count: 4)
            headerData.withUnsafeMutableBytes { bytes in
                bytes.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee = 0xeeeeeeee
            }
            self.connection.send(content: headerData, completion: .contentProcessed({ error in
                if let error = error {
                    OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection send header error: \(error)")
                }
            }))
            
            self.beginPingTimer()
            
            self.sendPacket(payload: Data())
        case let .failed(error):
            OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection error: \(error)")
            self.onIsClosed()
        default:
            break
        }
    }
    
    func start() {
        self.connection.start(queue: self.queue.queue)
        self.receivePacketHeader()
    }
    
    private func beginPingTimer() {
        self.pingTimer = SwiftSignalKit.Timer(timeout: self.isConnected ? 2.0 : 0.15, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.sendPacket(payload: Data())
            
            strongSelf.beginPingTimer()
        }, queue: self.queue)
        self.pingTimer?.start()
    }
    
    private func receivePacketHeader() {
        self.connection.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: { [weak self] data, _, _, error in
            guard let strongSelf = self else {
                return
            }
            if let data = data, data.count == 4 {
                let payloadSize = data.withUnsafeBytes { bytes -> UInt32 in
                    return bytes.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
                }
                if payloadSize < 2 * 1024 * 1024 {
                    strongSelf.receivePacketPayload(size: Int(payloadSize))
                } else {
                    OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection received invalid packet size: \(payloadSize)")
                }
            } else {
                OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection receive packet header error: \(String(describing: error))")
                strongSelf.onIsClosed()
            }
        })
    }
    
    private func receivePacketPayload(size: Int) {
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size, completion: { [weak self] data, _, _, error in
            guard let strongSelf = self else {
                return
            }
            if let data = data, data.count == size {
                OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection receive packet payload: \(data.count) bytes")
                
                if data.count < 16 + 4 {
                    OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection invalid payload size: \(data.count)")
                    strongSelf.onIsClosed()
                } else {
                    let readPeerTag = data.subdata(in: 0 ..< 16)
                    if readPeerTag != strongSelf.peerTag {
                        OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Peer tag mismatch: \(hexString(readPeerTag))")
                        strongSelf.onIsClosed()
                    } else {
                        let actualPayloadSize = data.withUnsafeBytes { bytes -> UInt32 in
                            var result: UInt32 = 0
                            memcpy(&result, bytes.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: 16), 4)
                            return result
                        }
                        
                        if Int(actualPayloadSize) > data.count - 16 - 4 {
                            OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection invalid actual payload size: \(actualPayloadSize)")
                            strongSelf.onIsClosed()
                        } else {
                            if !strongSelf.isConnected {
                                strongSelf.isConnected = true
                                
                                for payload in strongSelf.queuedPayloads {
                                    strongSelf.sendPacket(payload: payload)
                                }
                                strongSelf.queuedPayloads.removeAll()
                            }
                            
                            if actualPayloadSize != 0 {
                                strongSelf.dataReceived(data.subdata(in: (16 + 4) ..< (16 + 4 + Int(actualPayloadSize))))
                            } else {
                                //strongSelf.sendPacket(payload: Data())
                            }
                            strongSelf.receivePacketHeader()
                        }
                    }
                }
            } else {
                OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection receive packet payload error: \(String(describing: error))")
                strongSelf.onIsClosed()
            }
        })
    }
    
    func stop() {
        self.connection.stateUpdateHandler = nil
        self.connection.cancel()
    }
    
    private func onIsClosed() {
        self.connection.stateUpdateHandler = nil
        self.connection.cancel()
        
        self.isClosed()
    }
    
    func send(payloadData: Data) {
        if self.isConnected {
            self.sendPacket(payload: payloadData)
        } else {
            self.queuedPayloads.append(payloadData)
        }
    }
    
    private func sendPacket(payload: Data) {
        var payloadSize = UInt32(payload.count)
        let cleanSize = 16 + 4 + payloadSize
        let paddingSize = ((cleanSize + 3) & ~(4 - 1)) - cleanSize
        var totalSize = cleanSize + paddingSize
        
        var sendBuffer = Data(count: 4 + Int(totalSize))
        sendBuffer.withUnsafeMutableBytes { bytes in
            let baseAddress = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            
            memcpy(baseAddress, &totalSize, 4)
            
            self.peerTag.withUnsafeBytes { peerTagBytes -> Void in
                memcpy(baseAddress.advanced(by: 4), peerTagBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 16)
            }
            
            memcpy(baseAddress.advanced(by: 4 + 16), &payloadSize, 4)
            
            payload.withUnsafeBytes { payloadBytes -> Void in
                memcpy(baseAddress.advanced(by: 4 + 16 + 4), payloadBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), payloadBytes.count)
            }
        }
        
        OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Send packet payload: \(totalSize) bytes")
        
        self.connection.send(content: sendBuffer, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                OngoingCallThreadLocalContextWebrtc.logMessage("CallSignaling: Connection send payload error: \(error)")
            }
        }))
    }
}

private final class CallSignalingConnectionManager {
    private let queue: Queue
    
    private var nextConnectionId: Int = 0
    private var connections: [Int: CallSignalingConnection] = [:]
    
    init(queue: Queue, peerTag: Data, servers: [OngoingCallConnectionDescriptionWebrtc], dataReceived: @escaping (Data) -> Void) {
        self.queue = queue
        
        for server in servers {
            if server.hasTcp {
                let id = self.nextConnectionId
                self.nextConnectionId += 1
                if #available(iOS 12.0, *) {
                    let connection = CallSignalingConnectionImpl(queue: queue, host: server.ip, port: UInt16(server.port), peerTag: peerTag, dataReceived: { data in
                        dataReceived(data)
                    }, isClosed: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf
                    })
                    connections[id] = connection
                }
            }
        }
    }
    
    func start() {
        for (_, connection) in self.connections {
            connection.start()
        }
    }
    
    func stop() {
        for (_, connection) in self.connections {
            connection.stop()
        }
    }
    
    func send(payloadData: Data) {
        for (_, connection) in self.connections {
            connection.send(payloadData: payloadData)
        }
    }
}
