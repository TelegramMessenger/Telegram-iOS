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
            return AVAudioSessionCategoryPlayback
        case .playAndRecord, .voiceCall:
            return AVAudioSessionCategoryPlayAndRecord
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

private final class HolderRecord {
    let id: Int32
    let audioSessionType: ManagedAudioSessionType
    let control: ManagedAudioSessionControl
    let activate: (ManagedAudioSessionControl) -> Void
    let deactivate: () -> Signal<Void, NoError>
    let once: Bool
    var overrideSpeaker: Bool
    var active: Bool = false
    var deactivatingDisposable: Disposable? = nil
    
    init(id: Int32, audioSessionType: ManagedAudioSessionType, control: ManagedAudioSessionControl, activate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping () -> Signal<Void, NoError>, once: Bool, overrideSpeaker: Bool) {
        self.id = id
        self.audioSessionType = audioSessionType
        self.control = control
        self.activate = activate
        self.deactivate = deactivate
        self.once = once
        self.overrideSpeaker = overrideSpeaker
    }
}

public class ManagedAudioSessionControl {
    private let setupImpl: (Bool) -> Void
    private let activateImpl: () -> Void
    private let setSpeakerImpl: (Bool) -> Void
    
    fileprivate init(setupImpl: @escaping (Bool) -> Void, activateImpl: @escaping () -> Void, setSpeakerImpl: @escaping (Bool) -> Void) {
        self.setupImpl = setupImpl
        self.activateImpl = activateImpl
        self.setSpeakerImpl = setSpeakerImpl
    }
    
    public func setup(synchronous: Bool = false) {
        self.setupImpl(synchronous)
    }
    
    public func activate() {
        self.activateImpl()
    }
    
    public func setSpeaker(_ value: Bool) {
        self.setSpeakerImpl(value)
    }
}

public final class ManagedAudioSession {
    private var nextId: Int32 = 0
    private let queue = Queue()
    private var holders: [HolderRecord] = []
    private var currentTypeAndOverrideSpeaker: (ManagedAudioSessionType, Bool)?
    private var deactivateTimer: SwiftSignalKit.Timer?
    
    deinit {
        self.deactivateTimer?.invalidate()
    }
    
    func push(audioSessionType: ManagedAudioSessionType, overrideSpeaker: Bool = false, once: Bool = false, activate: @escaping () -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> Disposable {
        return self.push(audioSessionType: audioSessionType, once: once, manualActivate: { control in
            control.setup()
            control.activate()
            activate()
        }, deactivate: deactivate)
    }
    
    func push(audioSessionType: ManagedAudioSessionType, overrideSpeaker: Bool = false, once: Bool = false, manualActivate: @escaping (ManagedAudioSessionControl) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> Disposable {
        let id = OSAtomicIncrement32(&self.nextId)
        self.queue.async {
            self.holders.append(HolderRecord(id: id, audioSessionType: audioSessionType, control: ManagedAudioSessionControl(setupImpl: { [weak self] synchronous in
                if let strongSelf = self {
                    let f: () -> Void = {
                        for holder in strongSelf.holders {
                            if holder.id == id && holder.active {
                                strongSelf.setup(type: audioSessionType, overrideSpeaker: holder.overrideSpeaker)
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
            }, activateImpl: { [weak self] in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        for holder in strongSelf.holders {
                            if holder.id == id && holder.active {
                                strongSelf.activate()
                                break
                            }
                        }
                    }
                }
            }, setSpeakerImpl: { [weak self] value in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        for holder in strongSelf.holders {
                            if holder.id == id {
                                if holder.overrideSpeaker != value {
                                    holder.overrideSpeaker = value
                                }
                                
                                if holder.active {
                                    strongSelf.update(overrideSpeaker: value)
                                }
                            }
                        }
                    }
                }
            }), activate: manualActivate, deactivate: deactivate, once: once, overrideSpeaker: overrideSpeaker))
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
    
    private func updateHolders() {
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
                    
                    if activeIndex != self.holders.count - 1 {
                        if self.holders[activeIndex].audioSessionType == .voiceCall {
                            deactivate = false
                        } else {
                            deactivate = true
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
        
        if self.currentTypeAndOverrideSpeaker?.0 == .voiceCall {
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
    
    private func applyNone() {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        self.currentTypeAndOverrideSpeaker = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let error {
            print("ManagedAudioSession applyNone error \(error)")
        }
    }
    
    private func setup(type: ManagedAudioSessionType, overrideSpeaker: Bool) {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        
        if self.currentTypeAndOverrideSpeaker == nil || self.currentTypeAndOverrideSpeaker! != (type, overrideSpeaker) {
            self.currentTypeAndOverrideSpeaker = (type, overrideSpeaker)
            
            do {
                print("ManagedAudioSession setting category for \(type)")
                try AVAudioSession.sharedInstance().setCategory(nativeCategoryForType(type), with: AVAudioSessionCategoryOptions(rawValue: allowBluetoothForType(type) ? AVAudioSessionCategoryOptions.allowBluetooth.rawValue : 0))
                print("ManagedAudioSession setting active \(type != .none)")
                try AVAudioSession.sharedInstance().setMode(type == .voiceCall ? AVAudioSessionModeVoiceChat : AVAudioSessionModeDefault)
            } catch let error {
                print("ManagedAudioSession setup error \(error)")
            }
        }
    }
    
    private func activate() {
        if let (type, overrideSpeaker) = self.currentTypeAndOverrideSpeaker {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(overrideSpeaker ? .speaker : .none)
                
                if case .voiceCall = type {
                    try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
                }
            } catch let error {
                print("ManagedAudioSession activate error \(error)")
            }
        }
    }
    
    private func update(overrideSpeaker: Bool) {
        if let (type, currentOverrideSpeaker) = self.currentTypeAndOverrideSpeaker, currentOverrideSpeaker != overrideSpeaker {
            self.currentTypeAndOverrideSpeaker = (type, overrideSpeaker)
            do {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(overrideSpeaker ? .speaker : .none)
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
