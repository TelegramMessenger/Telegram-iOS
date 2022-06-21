import Foundation
import SwiftSignalKit
import AVFoundation
import UIKit

private var managedAudioSessionLogger: (String) -> Void = { _ in }

public func setManagedAudioSessionLogger(_ f: @escaping (String) -> Void) {
    managedAudioSessionLogger = f
}

func managedAudioSessionLog(_ what: @autoclosure () -> String) {
    managedAudioSessionLogger(what())
}


public enum ManagedAudioSessionType: Equatable {
    case ambient
    case play
    case playWithPossiblePortOverride
    case record(speaker: Bool)
    case voiceCall
    case videoCall
    case recordWithOthers
    
    var isPlay: Bool {
        switch self {
            case .play, .playWithPossiblePortOverride:
                return true
            default:
                return false
        }
    }
}

private func nativeCategoryForType(_ type: ManagedAudioSessionType, headphones: Bool, outputMode: AudioSessionOutputMode) -> AVAudioSession.Category {
    switch type {
    case .ambient:
        return .ambient
    case .play:
        return .playback
    case .record, .recordWithOthers, .voiceCall, .videoCall:
        return .playAndRecord
    case .playWithPossiblePortOverride:
        if headphones {
            return .playback
        } else {
            switch outputMode {
            case .custom(.speaker), .system:
                return .playAndRecord
            default:
                return .playback
            }
        }
    }
}

public enum AudioSessionPortType {
    case generic
    case bluetooth
}

public struct AudioSessionPort: Equatable {
    fileprivate let uid: String
    public let name: String
    public let type: AudioSessionPortType
}

public enum AudioSessionOutput: Equatable {
    case builtin
    case speaker
    case headphones
    case port(AudioSessionPort)
}

private let bluetoothPortTypes = Set<AVAudioSession.Port>([.bluetoothA2DP, .bluetoothLE, .bluetoothHFP])

private extension AudioSessionOutput {
    init(description: AVAudioSessionPortDescription) {
        self = .port(AudioSessionPort(uid: description.uid, name: description.portName, type: bluetoothPortTypes.contains(description.portType) ? .bluetooth : .generic))
    }
}

public enum AudioSessionOutputMode: Equatable {
    case system
    case speakerIfNoHeadphones
    case custom(AudioSessionOutput)
    
    public static func ==(lhs: AudioSessionOutputMode, rhs: AudioSessionOutputMode) -> Bool {
        switch lhs {
            case .system:
                if case .system = rhs {
                    return true
                } else {
                    return false
                }
            case .speakerIfNoHeadphones:
                if case .speakerIfNoHeadphones = rhs {
                    return true
                } else {
                    return false
                }
            case let .custom(output):
                if case .custom(output) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private final class HolderRecord {
    let id: Int32
    let audioSessionType: ManagedAudioSessionType
    let control: ManagedAudioSessionControl
    let activate: (ManagedAudioSessionControl) -> Void
    let deactivate: (Bool) -> Signal<Void, NoError>
    let headsetConnectionStatusChanged: (Bool) -> Void
    let availableOutputsChanged: ([AudioSessionOutput], AudioSessionOutput?) -> Void
    let once: Bool
    var outputMode: AudioSessionOutputMode
    var active: Bool = false
    var deactivatingDisposable: Disposable? = nil
    
    init(id: Int32, audioSessionType: ManagedAudioSessionType, control: ManagedAudioSessionControl, activate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping (Bool) -> Signal<Void, NoError>, headsetConnectionStatusChanged: @escaping (Bool) -> Void, availableOutputsChanged: @escaping ([AudioSessionOutput], AudioSessionOutput?) -> Void, once: Bool, outputMode: AudioSessionOutputMode) {
        self.id = id
        self.audioSessionType = audioSessionType
        self.control = control
        self.activate = activate
        self.deactivate = deactivate
        self.headsetConnectionStatusChanged = headsetConnectionStatusChanged
        self.availableOutputsChanged = availableOutputsChanged
        self.once = once
        self.outputMode = outputMode
    }
}

private final class ManagedAudioSessionControlActivate {
    let f: (AudioSessionActivationState) -> Void
    
    init(_ f: @escaping (AudioSessionActivationState) -> Void) {
        self.f = f
    }
}

public struct AudioSessionActivationState {
    public let isHeadsetConnected: Bool
}

public class ManagedAudioSessionControl {
    private let setupImpl: (Bool) -> Void
    private let activateImpl: (ManagedAudioSessionControlActivate) -> Void
    private let setupAndActivateImpl: (Bool, ManagedAudioSessionControlActivate) -> Void
    private let setOutputModeImpl: (AudioSessionOutputMode) -> Void
    
    fileprivate init(setupImpl: @escaping (Bool) -> Void, activateImpl: @escaping (ManagedAudioSessionControlActivate) -> Void, setOutputModeImpl: @escaping (AudioSessionOutputMode) -> Void, setupAndActivateImpl: @escaping (Bool, ManagedAudioSessionControlActivate) -> Void) {
        self.setupImpl = setupImpl
        self.activateImpl = activateImpl
        self.setOutputModeImpl = setOutputModeImpl
        self.setupAndActivateImpl = setupAndActivateImpl
    }
    
    public func setup(synchronous: Bool = false) {
        self.setupImpl(synchronous)
    }
    
    public func activate(_ completion: @escaping (AudioSessionActivationState) -> Void) {
        self.activateImpl(ManagedAudioSessionControlActivate(completion))
    }
    
    public func setupAndActivate(synchronous: Bool = false, _ completion: @escaping (AudioSessionActivationState) -> Void) {
        self.setupAndActivateImpl(synchronous, ManagedAudioSessionControlActivate(completion))
    }
    
    public func setOutputMode(_ mode: AudioSessionOutputMode) {
        self.setOutputModeImpl(mode)
    }
}

public final class ManagedAudioSession {
    private var nextId: Int32 = 0
    private let queue: Queue
    private let hasLoudspeaker: Bool
    private var holders: [HolderRecord] = []
    private var currentTypeAndOutputMode: (ManagedAudioSessionType, AudioSessionOutputMode)?
    private var deactivateTimer: SwiftSignalKit.Timer?
    
    private let isHeadsetPluggedInSync = Atomic<Bool>(value: false)
    private var isHeadsetPluggedInValue = false {
        didSet {
            if self.isHeadsetPluggedInValue != oldValue {
                let _ = self.isHeadsetPluggedInSync.swap(self.isHeadsetPluggedInValue)
            }
        }
    }
    
    public func getIsHeadsetPluggedIn() -> Bool {
        return self.isHeadsetPluggedInSync.with { $0 }
    }
    
    private let outputsToHeadphonesSubscribers = Bag<(Bool) -> Void>()
    
    private var availableOutputsValue: [AudioSessionOutput] = []
    private var currentOutputValue: AudioSessionOutput?
    
    private let isActiveSubscribers = Bag<(Bool) -> Void>()
    private let isPlaybackActiveSubscribers = Bag<(Bool) -> Void>()
    
    private var callKitAudioSessionIsActive: Bool = false
    
    public init() {
        self.queue = Queue()
        
        self.hasLoudspeaker = UIDevice.current.model == "iPhone"
        
        let queue = self.queue
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: nil, using: { [weak self] _ in
            queue.async {
                self?.updateCurrentAudioRouteInfo()
            }
        })
        
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: nil, using: { [weak self] notification in
            managedAudioSessionLog("Interruption received")

            guard let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
            }

            managedAudioSessionLog("Interruption type: \(type)")
            
            queue.async {
                if let strongSelf = self {
                    if type == .began {
                        strongSelf.updateHolders(interruption: true)
                    }
                }
            }
        })

        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification, object: AVAudioSession.sharedInstance(), queue: nil, using: { [weak self] _ in
            managedAudioSessionLog("Media Services were lost")
            queue.after(1.0, {
                if let strongSelf = self {
                    if let (type, outputMode) = strongSelf.currentTypeAndOutputMode {
                        strongSelf.setup(type: type, outputMode: outputMode, activateNow: true)
                    }
                }
            })
        })
        
        queue.async {
            self.isHeadsetPluggedInValue = self.isHeadsetPluggedIn()
            self.updateCurrentAudioRouteInfo()
        }
    }
    
    deinit {
        self.deactivateTimer?.invalidate()
    }
    
    private func updateCurrentAudioRouteInfo() {
        let value = self.isHeadsetPluggedIn()
        if self.isHeadsetPluggedInValue != value {
            self.isHeadsetPluggedInValue = value
            if let (_, outputMode) = self.currentTypeAndOutputMode {
                if case .speakerIfNoHeadphones = outputMode {
                    self.updateOutputMode(outputMode)
                }
            }
            for subscriber in self.outputsToHeadphonesSubscribers.copyItems() {
                subscriber(value)
            }
            for i in 0 ..< self.holders.count {
                if self.holders[i].active {
                    self.holders[i].headsetConnectionStatusChanged(value)
                    break
                }
            }
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        var availableOutputs: [AudioSessionOutput] = []
        var activeOutput: AudioSessionOutput = .builtin
        
        if let availableInputs = audioSession.availableInputs {
            var hasHeadphones = false
            var hasBluetoothHeadphones = false
            
            var headphonesAreActive = false
            loop: for currentOutput in audioSession.currentRoute.outputs {
                switch currentOutput.portType {
                case .headphones, .bluetoothA2DP, .bluetoothHFP:
                    headphonesAreActive = true
                    hasHeadphones = true
                    hasBluetoothHeadphones = [.bluetoothA2DP, .bluetoothHFP].contains(currentOutput.portType)
                    activeOutput = .headphones
                    break loop
                default:
                    break
                }
            }
            
            for input in availableInputs {
                var isActive = false
                for currentInput in audioSession.currentRoute.inputs {
                    if currentInput.uid == input.uid {
                        isActive = true
                    }
                }
                
                if input.portType == .builtInMic {
                    if isActive && !headphonesAreActive {
                        activeOutput = .builtin
                        inner: for currentOutput in audioSession.currentRoute.outputs {
                            if currentOutput.portType == .builtInSpeaker {
                                activeOutput = .speaker
                                break inner
                            }
                        }
                    }
                    continue
                }
                if input.portType == .headphones {
                    if isActive {
                        activeOutput = .headphones
                    }
                    hasHeadphones = true
                    continue
                }
                let output = AudioSessionOutput(description: input)
                availableOutputs.append(output)
                if isActive {
                    activeOutput = output
                }
            }
            
            if self.hasLoudspeaker {
                availableOutputs.insert(.speaker, at: 0)
            }
            
            if hasHeadphones && !hasBluetoothHeadphones {
                availableOutputs.insert(.headphones, at: 0)
            }
            availableOutputs.insert(.builtin, at: 0)
        }
        
        if self.availableOutputsValue != availableOutputs || self.currentOutputValue != activeOutput {
            self.availableOutputsValue = availableOutputs
            self.currentOutputValue = activeOutput
            for i in 0 ..< self.holders.count {
                if self.holders[i].active {
                    self.holders[i].availableOutputsChanged(availableOutputs, activeOutput)
                    break
                }
            }
        }
    }
    
    public func headsetConnected() -> Signal<Bool, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.isHeadsetPluggedInValue)
                
                let index = strongSelf.outputsToHeadphonesSubscribers.add({ value in
                    subscriber.putNext(value)
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.outputsToHeadphonesSubscribers.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(queue)
    }
    
    public func isActive() -> Signal<Bool, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.currentTypeAndOutputMode != nil)
                
                let index = strongSelf.isActiveSubscribers.add({ value in
                    subscriber.putNext(value)
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.isActiveSubscribers.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(queue)
    }
    
    public func isPlaybackActive() -> Signal<Bool, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.currentTypeAndOutputMode?.0.isPlay ?? false)
                
                let index = strongSelf.isPlaybackActiveSubscribers.add({ value in
                    subscriber.putNext(value)
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.isPlaybackActiveSubscribers.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(queue)
    }
    
    public func isOtherAudioPlaying() -> Bool {
        return AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }
    
    public func push(audioSessionType: ManagedAudioSessionType, outputMode: AudioSessionOutputMode = .system, once: Bool = false, activate: @escaping (AudioSessionActivationState) -> Void, deactivate: @escaping (Bool) -> Signal<Void, NoError>) -> Disposable {
        return self.push(audioSessionType: audioSessionType, once: once, manualActivate: { control in
            control.setupAndActivate(synchronous: false, { state in
                activate(state)
            })
        }, deactivate: deactivate)
    }
    
    public func push(audioSessionType: ManagedAudioSessionType, outputMode: AudioSessionOutputMode = .system, once: Bool = false, activateImmediately: Bool = false, manualActivate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping (Bool) -> Signal<Void, NoError>, headsetConnectionStatusChanged: @escaping (Bool) -> Void = { _ in }, availableOutputsChanged: @escaping ([AudioSessionOutput], AudioSessionOutput?) -> Void = { _, _ in }) -> Disposable {
        let id = OSAtomicIncrement32(&self.nextId)
        let queue = self.queue
        queue.async {
            self.holders.append(HolderRecord(id: id, audioSessionType: audioSessionType, control: ManagedAudioSessionControl(setupImpl: { [weak self] synchronous in
                let f: () -> Void = {
                    if let strongSelf = self {
                        for holder in strongSelf.holders {
                            if holder.id == id && holder.active {
                                strongSelf.setup(type: audioSessionType, outputMode: holder.outputMode, activateNow: activateImmediately)
                                break
                            }
                        }
                    }
                }
                
                if synchronous {
                    queue.sync(f)
                } else {
                    queue.async(f)
                }
            }, activateImpl: { [weak self] completion in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        for holder in strongSelf.holders {
                            if holder.id == id && holder.active {
                                strongSelf.activate()
                                completion.f(AudioSessionActivationState(isHeadsetConnected: strongSelf.isHeadsetPluggedInValue))
                                break
                            }
                        }
                    }
                }
            }, setOutputModeImpl: { [weak self] value in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        for holder in strongSelf.holders {
                            if holder.id == id {
                                if holder.outputMode != value {
                                    holder.outputMode = value
                                }
                                
                                if holder.active {
                                    strongSelf.updateOutputMode(value)
                                }
                            }
                        }
                    }
                }
            }, setupAndActivateImpl: { [weak self] synchronous, completion in
                queue.async {
                    let f: () -> Void = {
                        if let strongSelf = self {
                            for holder in strongSelf.holders {
                                if holder.id == id && holder.active {
                                    strongSelf.setup(type: audioSessionType, outputMode: holder.outputMode, activateNow: true)
                                    completion.f(AudioSessionActivationState(isHeadsetConnected: strongSelf.isHeadsetPluggedInValue))
                                    break
                                }
                            }
                        }
                    }
                    
                    if synchronous {
                        queue.sync(f)
                    } else {
                        queue.async(f)
                    }
                }
            }), activate: { [weak self] state in
                manualActivate(state)
                queue.async {
                    if let strongSelf = self {
                        strongSelf.updateCurrentAudioRouteInfo()
                        availableOutputsChanged(strongSelf.availableOutputsValue, strongSelf.currentOutputValue)
                    }
                }
            }, deactivate: deactivate, headsetConnectionStatusChanged: headsetConnectionStatusChanged, availableOutputsChanged: availableOutputsChanged, once: once, outputMode: outputMode))
            self.updateHolders()
        }
        return ActionDisposable { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    strongSelf.removeDeactivatedHolder(id: id)
                }
            }
        }
    }

    public func dropAll() {
        self.queue.async {
            self.updateHolders(interruption: true)
        }
    }
    
    private func removeDeactivatedHolder(id: Int32) {
        assert(self.queue.isCurrent())
        
        for i in 0 ..< self.holders.count {
            if self.holders[i].id == id {
                self.holders[i].deactivatingDisposable?.dispose()
                self.holders.remove(at: i)
                self.updateHolders()
                break
            }
        }
    }
    
    private func updateHolders(interruption: Bool = false) {
        assert(self.queue.isCurrent())
        
        managedAudioSessionLog("holder count \(self.holders.count)")
        
        if !self.holders.isEmpty {
            var activeIndex: Int?
            var deactivating = false
            var index = 0
            for record in self.holders {
                if record.active {
                    activeIndex = index
                    break
                }
                else if record.deactivatingDisposable != nil {
                    deactivating = true
                }
                index += 1
            }
            
            var lastIsRecordWithOthers = false // self.holders.last?.audioSessionType == .recordWithOthers
            if "".count != 0 {
                // Silence warning
                lastIsRecordWithOthers = true
            }
            if !deactivating {
                if let activeIndex = activeIndex {
                    var deactivate = false
                    var temporary = false
                    
                    if interruption {
                        if self.holders[activeIndex].audioSessionType != .voiceCall {
                            deactivate = true
                        }
                    } else {
                        if activeIndex != self.holders.count - 1 {
                            if lastIsRecordWithOthers {
                                deactivate = true
                                temporary = true
                            } else if self.holders[activeIndex].audioSessionType == .voiceCall {
                                deactivate = false
                            } else {
                                deactivate = true
                            }
                        }
                    }
                    
                    if deactivate {
                        self.holders[activeIndex].active = false
                        let id = self.holders[activeIndex].id
                        self.holders[activeIndex].deactivatingDisposable = (self.holders[activeIndex].deactivate(temporary)
                        |> deliverOn(self.queue)).start(completed: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            var index = 0
                            for currentRecord in strongSelf.holders {
                                if currentRecord.id == id {
                                    currentRecord.deactivatingDisposable = nil
                                    if currentRecord.once {
                                        strongSelf.holders.remove(at: index)
                                    }
                                    break
                                }
                                index += 1
                            }
                            strongSelf.updateHolders()
                        })
                    }
                } else if activeIndex == nil {
                    let lastIndex = self.holders.count - 1
                    
                    self.deactivateTimer?.invalidate()
                    self.deactivateTimer = nil
                    
                    self.holders[lastIndex].active = true
                    self.holders[lastIndex].activate(self.holders[lastIndex].control)
                }
            }
        } else {
            self.applyNoneDelayed()
        }
    }
    
    private func applyNoneDelayed() {
        self.deactivateTimer?.invalidate()
        
        var immediately = false
        if let mode = self.currentTypeAndOutputMode?.0 {
            switch mode {
                case .voiceCall, .record:
                    immediately = true
                default:
                    break
            }
        }
        
        if immediately {
            self.applyNone()
        } else {
            let deactivateTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.applyNone()
                }
            }, queue: self.queue)
            self.deactivateTimer = deactivateTimer
            deactivateTimer.start()
        }
    }
    
    private func isHeadsetPluggedIn() -> Bool {
        assert(self.queue.isCurrent())
        
        let route = AVAudioSession.sharedInstance().currentRoute
        //managedAudioSessionLog("\(route)")
        for desc in route.outputs {
            if desc.portType == .headphones || desc.portType == .bluetoothA2DP || desc.portType == .bluetoothHFP {
                return true
            }
        }
        
        return false
    }
    
    private func applyNone() {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        let wasActive = self.currentTypeAndOutputMode != nil
        let wasPlaybackActive = self.currentTypeAndOutputMode?.0.isPlay ?? false
        self.currentTypeAndOutputMode = nil
        
        managedAudioSessionLog("ManagedAudioSession setting active false")
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            try AVAudioSession.sharedInstance().setPreferredInput(nil)
        } catch let error {
            managedAudioSessionLog("ManagedAudioSession applyNone error \(error), waiting")

            Thread.sleep(forTimeInterval: 2.0)

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                try AVAudioSession.sharedInstance().setPreferredInput(nil)
            } catch let error {
                managedAudioSessionLog("ManagedAudioSession applyNone repeated error \(error), giving up")
            }
        }
        
        if wasActive {
            for subscriber in self.isActiveSubscribers.copyItems() {
                subscriber(false)
            }
        }
        if wasPlaybackActive {
            for subscriber in self.isPlaybackActiveSubscribers.copyItems() {
                subscriber(false)
            }
        }
    }
    
    private func setup(type: ManagedAudioSessionType, outputMode: AudioSessionOutputMode, activateNow: Bool) {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        let wasActive = self.currentTypeAndOutputMode != nil
        let wasPlaybackActive = self.currentTypeAndOutputMode?.0.isPlay ?? false
        
        if self.currentTypeAndOutputMode == nil || self.currentTypeAndOutputMode! != (type, outputMode) {
            self.currentTypeAndOutputMode = (type, outputMode)
            
            do {
                let nativeCategory = nativeCategoryForType(type, headphones: self.isHeadsetPluggedInValue, outputMode: outputMode)
                
                managedAudioSessionLog("ManagedAudioSession setting category for \(type) (native: \(nativeCategory)) activateNow: \(activateNow)")
                var options: AVAudioSession.CategoryOptions = []
                switch type {
                    case .play, .ambient:
                        break
                    case .playWithPossiblePortOverride:
                        if case .playAndRecord = nativeCategory {
                            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                                options.insert(.allowBluetoothA2DP)
                            } else {
                                options.insert(.allowBluetooth)
                            }
                        }
                    case .record, .recordWithOthers, .voiceCall, .videoCall:
                        options.insert(.allowBluetooth)
                }
                managedAudioSessionLog("ManagedAudioSession setting active true")
                let mode: AVAudioSession.Mode
                switch type {
                    case .voiceCall:
                        mode = .voiceChat
                        options.insert(.mixWithOthers)
                    case .videoCall:
                        mode = .videoChat
                        options.insert(.mixWithOthers)
//                    case .recordWithOthers:
//                        mode = .videoRecording
//                        options.insert(.mixWithOthers)
                    default:
                        mode = .default
                }
                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                    try AVAudioSession.sharedInstance().setCategory(nativeCategory, mode: mode, policy: .default, options: options)
                } else {
                    AVAudioSession.sharedInstance().perform(NSSelectorFromString("setCategory:error:"), with: nativeCategory)
                    try AVAudioSession.sharedInstance().setMode(mode)
                }
            } catch let error {
                managedAudioSessionLog("ManagedAudioSession setup error \(error)")
            }
        }
        
        if !wasActive {
            for subscriber in self.isActiveSubscribers.copyItems() {
                subscriber(true)
            }
        }
        if !wasPlaybackActive && (self.currentTypeAndOutputMode?.0.isPlay ?? false) {
            for subscriber in self.isPlaybackActiveSubscribers.copyItems() {
                subscriber(true)
            }
        }
        
        if activateNow {
            self.activate()
        }
    }
    
    private func setupOutputMode(_ outputMode: AudioSessionOutputMode, type: ManagedAudioSessionType) throws {
        managedAudioSessionLog("ManagedAudioSession setup \(outputMode) for \(type)")
        var resetToBuiltin = false
        switch outputMode {
        case .system:
            resetToBuiltin = true
        case let .custom(output):
            switch output {
                case .builtin:
                    resetToBuiltin = true
                case .speaker:
                    if type == .voiceCall {
                        if let routes = AVAudioSession.sharedInstance().availableInputs {
                            for route in routes {
                                if route.portType == .builtInMic {
                                    let _ = try? AVAudioSession.sharedInstance().setPreferredInput(route)
                                    break
                                }
                            }
                        }
                    }
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                case .headphones:
                    break
                case let .port(port):
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                    if let routes = AVAudioSession.sharedInstance().availableInputs {
                        for route in routes {
                            if route.uid == port.uid {
                                let _ = try? AVAudioSession.sharedInstance().setPreferredInput(route)
                                break
                            }
                        }
                    }
            }
        case .speakerIfNoHeadphones:
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        }
        
        if resetToBuiltin {
            var updatedType = type
            if case .record(false) = updatedType, self.isHeadsetPluggedInValue {
                updatedType = .record(speaker: true)
            }
            switch updatedType {
                case .record(false):
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                case .voiceCall, .playWithPossiblePortOverride, .record(true):
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                    if let routes = AVAudioSession.sharedInstance().availableInputs {
                        var alreadySet = false
                        if self.isHeadsetPluggedInValue {
                            if case .voiceCall = updatedType, case .custom(.builtin) = outputMode {
                            } else {
                                loop: for route in routes {
                                    switch route.portType {
                                    case .headphones, .bluetoothA2DP, .bluetoothHFP:
                                        let _ = try? AVAudioSession.sharedInstance().setPreferredInput(route)
                                        alreadySet = true
                                        break loop
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                        if !alreadySet {
                            for route in routes {
                                if route.portType == .builtInMic {
                                    if case .record = updatedType, self.isHeadsetPluggedInValue {
                                    } else {
                                        let _ = try? AVAudioSession.sharedInstance().setPreferredInput(route)
                                    }
                                    break
                                }
                            }
                        }
                    }
                default:
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            }
        }
    }
    
    private func activate() {
        if let (type, outputMode) = self.currentTypeAndOutputMode {
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
                
                managedAudioSessionLog("\(CFAbsoluteTimeGetCurrent()) AudioSession activate: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                try self.setupOutputMode(outputMode, type: type)
                
                managedAudioSessionLog("\(CFAbsoluteTimeGetCurrent()) AudioSession setupOutputMode: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                self.updateCurrentAudioRouteInfo()
                
                managedAudioSessionLog("\(CFAbsoluteTimeGetCurrent()) AudioSession updateCurrentAudioRouteInfo: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                if case .voiceCall = type {
                    try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
                }
            } catch let error {
                managedAudioSessionLog("ManagedAudioSession activate error \(error)")
            }
        }
    }
    
    private func updateOutputMode(_ outputMode: AudioSessionOutputMode) {
        if let (type, _) = self.currentTypeAndOutputMode {
            self.setup(type: type, outputMode: outputMode, activateNow: true)
        }
    }
    
    public func callKitActivatedAudioSession() {
        self.queue.async {
            managedAudioSessionLog("ManagedAudioSession callKitDeactivatedAudioSession")
            self.callKitAudioSessionIsActive = true
            self.updateHolders()
        }
    }
    
    public func callKitDeactivatedAudioSession() {
        self.queue.async {
            managedAudioSessionLog("ManagedAudioSession callKitDeactivatedAudioSession")
            self.callKitAudioSessionIsActive = false
            self.updateHolders()
        }
    }
}
