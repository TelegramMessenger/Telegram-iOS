import Foundation
import SwiftSignalKit
import AVFoundation

enum ManagedAudioSessionType {
    case play
    case playAndRecord
    case voiceCall
}

private func nativeCategoryForType(_ type: ManagedAudioSessionType) -> String {
    switch type {
        case .play:
            return "AVAudioSessionCategoryPlayback"
        case .playAndRecord, .voiceCall:
            return "AVAudioSessionCategoryPlayAndRecord"
    }
}

private func allowBluetoothForType(_ type: ManagedAudioSessionType) -> Bool {
    switch type {
        case .play:
            return false
        case .playAndRecord, .voiceCall:
            return true
    }
}

public enum AudioSessionOutput {
    case speaker
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
    let deactivate: () -> Signal<Void, NoError>
    let headsetConnectionStatusChanged: (Bool) -> Void
    let once: Bool
    var outputMode: AudioSessionOutputMode
    var active: Bool = false
    var deactivatingDisposable: Disposable? = nil
    
    init(id: Int32, audioSessionType: ManagedAudioSessionType, control: ManagedAudioSessionControl, activate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping () -> Signal<Void, NoError>, headsetConnectionStatusChanged: @escaping (Bool) -> Void, once: Bool, outputMode: AudioSessionOutputMode) {
        self.id = id
        self.audioSessionType = audioSessionType
        self.control = control
        self.activate = activate
        self.deactivate = deactivate
        self.headsetConnectionStatusChanged = headsetConnectionStatusChanged
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
    private let setOutputModeImpl: (AudioSessionOutputMode) -> Void
    
    fileprivate init(setupImpl: @escaping (Bool) -> Void, activateImpl: @escaping (ManagedAudioSessionControlActivate) -> Void, setOutputModeImpl: @escaping (AudioSessionOutputMode) -> Void) {
        self.setupImpl = setupImpl
        self.activateImpl = activateImpl
        self.setOutputModeImpl = setOutputModeImpl
    }
    
    public func setup(synchronous: Bool = false) {
        self.setupImpl(synchronous)
    }
    
    public func activate(_ completion: @escaping (AudioSessionActivationState) -> Void) {
        self.activateImpl(ManagedAudioSessionControlActivate(completion))
    }
    
    public func setOutputMode(_ mode: AudioSessionOutputMode) {
        self.setOutputModeImpl(mode)
    }
}

public final class ManagedAudioSession {
    private var nextId: Int32 = 0
    private let queue = Queue()
    private var holders: [HolderRecord] = []
    private var currentTypeAndOutputMode: (ManagedAudioSessionType, AudioSessionOutputMode)?
    private var deactivateTimer: SwiftSignalKit.Timer?
    
    private var isHeadsetPluggedInValue = false
    private let outputsToHeadphonesSubscribers = Bag<(Bool) -> Void>()
    private let isActiveSubscribers = Bag<(Bool) -> Void>()
    
    init() {
        let queue = self.queue
        
        
        queue.async {
            self.isHeadsetPluggedInValue = self.isHeadsetPluggedIn()
        }
    }
    
    deinit {
        self.deactivateTimer?.invalidate()
    }
    
    func headsetConnected() -> Signal<Bool, NoError> {
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
    
    func push(audioSessionType: ManagedAudioSessionType, outputMode: AudioSessionOutputMode = .system, once: Bool = false, activate: @escaping (AudioSessionActivationState) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> Disposable {
        return self.push(audioSessionType: audioSessionType, once: once, manualActivate: { control in
            control.setup()
            control.activate({ state in
                activate(state)
            })
        }, deactivate: deactivate)
    }
    
    func push(audioSessionType: ManagedAudioSessionType, outputMode: AudioSessionOutputMode = .system, once: Bool = false, manualActivate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping () -> Signal<Void, NoError>, headsetConnectionStatusChanged: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let id = OSAtomicIncrement32(&self.nextId)
        self.queue.async {
            self.holders.append(HolderRecord(id: id, audioSessionType: audioSessionType, control: ManagedAudioSessionControl(setupImpl: { [weak self] synchronous in
                if let strongSelf = self {
                    let f: () -> Void = {
                        for holder in strongSelf.holders {
                            if holder.id == id && holder.active {
                                strongSelf.setup(type: audioSessionType, outputMode: holder.outputMode)
                                break
                            }
                        }
                    }
                    
                    if synchronous {
                        strongSelf.queue.sync(f)
                    } else {
                        strongSelf.queue.async(f)
                    }
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
            }), activate: manualActivate, deactivate: deactivate, headsetConnectionStatusChanged: headsetConnectionStatusChanged, once: once, outputMode: outputMode))
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
    
    func dropAll() {
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
        
        print("holder count \(self.holders.count)")
        
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
            if !deactivating {
                if let activeIndex = activeIndex {
                    var deactivate = false
                    
                    if interruption {
                        if self.holders[activeIndex].audioSessionType != .voiceCall {
                            deactivate = true
                        }
                    } else {
                        if activeIndex != self.holders.count - 1 {
                            if self.holders[activeIndex].audioSessionType == .voiceCall {
                                deactivate = false
                            } else {
                                deactivate = true
                            }
                        }
                    }
                    
                    if deactivate {
                        self.holders[activeIndex].active = false
                        let id = self.holders[activeIndex].id
                        self.holders[activeIndex].deactivatingDisposable = (self.holders[activeIndex].deactivate() |> deliverOn(self.queue)).start(completed: { [weak self] in
                            if let strongSelf = self {
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
                            }
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
        
        if self.currentTypeAndOutputMode?.0 == .voiceCall {
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
        
//        let route = AVAudioSession.sharedInstance().currentRoute
//        //print("\(route)")
//        for desc in route.outputs {
//            if desc.portType == AVAudioSessionPortHeadphones || desc.portType == AVAudioSessionPortBluetoothA2DP || desc.portType == AVAudioSessionPortBluetoothHFP {
//                return true
//            }
//        }
        
        return false
    }
    
    private func applyNone() {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        let wasActive = self.currentTypeAndOutputMode != nil
        self.currentTypeAndOutputMode = nil
        
//        print("ManagedAudioSession setting active false")
//        do {
//            try AVAudioSession.sharedInstance().setActive(false, with: [.notifyOthersOnDeactivation])
//        } catch let error {
//            print("ManagedAudioSession applyNone error \(error)")
//        }
        
        if wasActive {
            for subscriber in self.isActiveSubscribers.copyItems() {
                subscriber(false)
            }
        }
    }
    
    private func setup(type: ManagedAudioSessionType, outputMode: AudioSessionOutputMode) {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        let wasActive = self.currentTypeAndOutputMode != nil
        
        if self.currentTypeAndOutputMode == nil || self.currentTypeAndOutputMode! != (type, outputMode) {
            self.currentTypeAndOutputMode = (type, outputMode)
//
//            do {
//                print("ManagedAudioSession setting category for \(type)")
//                try AVAudioSession.sharedInstance().setCategory(nativeCategoryForType(type), with: AVAudioSessionCategoryOptions(rawValue: allowBluetoothForType(type) ? AVAudioSessionCategoryOptions.allowBluetooth.rawValue : 0))
//                print("ManagedAudioSession setting active \(type != .none)")
//                try AVAudioSession.sharedInstance().setMode(type == .voiceCall ? AVAudioSessionModeVoiceChat : AVAudioSessionModeDefault)
//            } catch let error {
//                print("ManagedAudioSession setup error \(error)")
//            }
        }
        
        if !wasActive {
            for subscriber in self.isActiveSubscribers.copyItems() {
                subscriber(true)
            }
        }
    }
    
    private func setupOutputMode(_ outputMode: AudioSessionOutputMode) throws {
//        switch outputMode {
//            case .system:
//                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
//            case let .custom(output):
//                switch output {
//                    case .speaker:
//                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
//                }
//            case .speakerIfNoHeadphones:
//                if !self.isHeadsetPluggedInValue {
//                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
//                }
//        }
    }
    
    private func activate() {
        if let (type, outputMode) = self.currentTypeAndOutputMode {
//            do {
//                try AVAudioSession.sharedInstance().setActive(true)
//
//                try self.setupOutputMode(outputMode)
//
//                if case .voiceCall = type {
//                    try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
//                }
//            } catch let error {
//                print("ManagedAudioSession activate error \(error)")
//            }
        }
    }
    
    private func updateOutputMode(_ outputMode: AudioSessionOutputMode) {
        if let (type, currentOutputMode) = self.currentTypeAndOutputMode, currentOutputMode != outputMode {
            self.currentTypeAndOutputMode = (type, outputMode)
            do {
                try self.setupOutputMode(outputMode)
            } catch let error {
                print("ManagedAudioSession overrideOutputAudioPort error \(error)")
            }
        }
    }
    
    func callKitActivatedAudioSession() {
        /*self.queue.async {
            print("ManagedAudioSession callKitDeactivatedAudioSession")
            self.callKitAudioSessionIsActive = true
            self.updateHolders()
        }*/
    }
    
    func callKitDeactivatedAudioSession() {
        /*self.queue.async {
            print("ManagedAudioSession callKitDeactivatedAudioSession")
            self.callKitAudioSessionIsActive = false
            self.updateHolders()
        }*/
    }
}
