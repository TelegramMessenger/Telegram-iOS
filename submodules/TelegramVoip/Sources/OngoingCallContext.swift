import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

import TgVoip
import TgVoipWebrtc

private func callConnectionDescription(_ connection: CallSessionConnection) -> OngoingCallConnectionDescription? {
    switch connection {
    case let .reflector(reflector):
        return OngoingCallConnectionDescription(connectionId: reflector.id, ip: reflector.ip, ipv6: reflector.ipv6, port: reflector.port, peerTag: reflector.peerTag)
    case .webRtcReflector:
        return nil
    }
}

private func callConnectionDescriptionsWebrtc(_ connection: CallSessionConnection) -> [OngoingCallConnectionDescriptionWebrtc] {
    switch connection {
    case let .reflector(reflector):
        #if DEBUG
        var result: [OngoingCallConnectionDescriptionWebrtc] = []
        if !reflector.ip.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(connectionId: reflector.id, hasStun: false, hasTurn: true, ip: reflector.ip, port: reflector.port, username: "reflector", password: hexString(reflector.peerTag)))
        }
        if !reflector.ipv6.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(connectionId: reflector.id, hasStun: false, hasTurn: true, ip: reflector.ipv6, port: reflector.port, username: "reflector", password: hexString(reflector.peerTag)))
        }
        return result
        #else
        return []
        #endif
    case let .webRtcReflector(reflector):
        var result: [OngoingCallConnectionDescriptionWebrtc] = []
        if !reflector.ip.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(connectionId: reflector.id, hasStun: reflector.hasStun, hasTurn: reflector.hasTurn, ip: reflector.ip, port: reflector.port, username: reflector.username, password: reflector.password))
        }
        if !reflector.ipv6.isEmpty {
            result.append(OngoingCallConnectionDescriptionWebrtc(connectionId: reflector.id, hasStun: reflector.hasStun, hasTurn: reflector.hasTurn, ip: reflector.ipv6, port: reflector.port, username: reflector.username, password: reflector.password))
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
    /*OngoingCallThreadLocalContextWebrtcCustom.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })*/
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
    
    public static func versions(includeExperimental: Bool, includeReference: Bool) -> [(version: String, supportsVideo: Bool)] {
        var result: [(version: String, supportsVideo: Bool)] = [(OngoingCallThreadLocalContext.version(), false)]
        if includeExperimental {
            result.append(contentsOf: OngoingCallThreadLocalContextWebrtc.versions(withIncludeReference: includeReference).map { version -> (version: String, supportsVideo: Bool) in
                return (version, true)
            })
        }
        return result
    }

    public init(account: Account, callSessionManager: CallSessionManager, internalId: CallSessionInternalId, proxyServer: ProxyServerSettings?, initialNetworkType: NetworkType, updatedNetworkType: Signal<NetworkType, NoError>, serializedData: String?, dataSaving: VoiceCallDataSaving, derivedState: VoipDerivedState, key: Data, isOutgoing: Bool, video: OngoingCallVideoCapturer?, connections: CallSessionConnectionSet, maxLayer: Int32, version: String, allowP2P: Bool, enableTCP: Bool, enableStunMarking: Bool, audioSessionActive: Signal<Bool, NoError>, logName: String, preferredVideoCodec: String?) {
        let _ = setupLogs
        OngoingCallThreadLocalContext.applyServerConfig(serializedData)
        
        #if DEBUG
        let version = "4.1.2"
        let allowP2P = false
        #endif
        
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
                if OngoingCallThreadLocalContextWebrtc.versions(withIncludeReference: true).contains(version) {
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
                    var processedConnections: [CallSessionConnection] = []
                    var filteredConnections: [OngoingCallConnectionDescriptionWebrtc] = []
                    for connection in unfilteredConnections {
                        if processedConnections.contains(connection) {
                            continue
                        }
                        processedConnections.append(connection)
                        filteredConnections.append(contentsOf: callConnectionDescriptionsWebrtc(connection))
                    }
                    
                    /*#if DEBUG
                    filteredConnections.removeAll()
                    filteredConnections.append(OngoingCallConnectionDescriptionWebrtc(
                        connectionId: 1,
                        hasStun: true,
                        hasTurn: true, ip: "178.62.7.192",
                        port: 1400,
                        username: "user",
                        password: "user")
                    )
                    #endif*/
                    
                    let context = OngoingCallThreadLocalContextWebrtc(version: version, queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, networkType: ongoingNetworkTypeForTypeWebrtc(initialNetworkType), dataSaving: ongoingDataSavingForTypeWebrtc(dataSaving), derivedState: derivedState.data, key: key, isOutgoing: isOutgoing, connections: filteredConnections, maxLayer: maxLayer, allowP2P: allowP2P, allowTCP: enableTCP, enableStunMarking: enableStunMarking, logPath: tempLogPath, statsLogPath: tempStatsLogPath, sendSignalingData: { [weak callSessionManager] data in
                        callSessionManager?.sendSignalingData(internalId: internalId, data: data)
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
                    let context = OngoingCallThreadLocalContext(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, networkType: ongoingNetworkTypeForType(initialNetworkType), dataSaving: ongoingDataSavingForType(dataSaving), derivedState: derivedState.data, key: key, isOutgoing: isOutgoing, primaryConnection: callConnectionDescription(connections.primary)!, alternativeConnections: connections.alternatives.compactMap(callConnectionDescription), maxLayer: maxLayer, allowP2P: allowP2P, logPath: logPath)
                    
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
    
    public func stop(callId: CallId? = nil, sendDebugLogs: Bool = false, debugLogValue: Promise<String?>) {
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
                
                if let callId = callId, !statsLogPath.isEmpty, let data = try? Data(contentsOf: URL(fileURLWithPath: statsLogPath)), let dataString = String(data: data, encoding: .utf8) {
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
            let derivedState = context.nativeGetDerivedState()
            let _ = updateVoipDerivedStateInteractively(postbox: self.account.postbox, { _ in
                return VoipDerivedState(data: derivedState)
            }).start()
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
