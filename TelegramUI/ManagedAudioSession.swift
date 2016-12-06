import Foundation
import SwiftSignalKit
import AVFoundation

enum ManagedAudioSessionType {
    case none
    case play
    case playAndRecord
}

private func nativeCategoryForType(_ type: ManagedAudioSessionType) -> String {
    switch type {
        case .none:
            return AVAudioSessionCategoryPlayback
        case .play:
            return AVAudioSessionCategoryPlayback
        case .playAndRecord:
            return AVAudioSessionCategoryPlayAndRecord
    }
}

private final class HolderRecord {
    let id: Int32
    let audioSessionType: ManagedAudioSessionType
    let activate: () -> Void
    let deactivate: () -> Signal<Void, NoError>
    var active: Bool = false
    var deactivatingDisposable: Disposable? = nil
    
    init(id: Int32, audioSessionType: ManagedAudioSessionType, activate: @escaping () -> Void, deactivate: @escaping () -> Signal<Void, NoError>) {
        self.id = id
        self.audioSessionType = audioSessionType
        self.activate = activate
        self.deactivate = deactivate
    }
}

final class ManagedAudioSession {
    private var nextId: Int32 = 0
    private let queue = Queue()
    private var holders: [HolderRecord] = []
    private var currentType: ManagedAudioSessionType = .none
    
    func push(audioSessionType: ManagedAudioSessionType, activate: @escaping () -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> Disposable {
        let id = OSAtomicIncrement32(&self.nextId)
        self.queue.async {
            self.holders.append(HolderRecord(id: id, audioSessionType: audioSessionType, activate: activate, deactivate: deactivate))
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
                if let activeIndex = activeIndex, activeIndex != self.holders.count - 1 {
                    self.holders[activeIndex].active = false
                    let id = self.holders[activeIndex].id
                    self.holders[activeIndex].deactivatingDisposable = (self.holders[activeIndex].deactivate() |> deliverOn(self.queue)).start(completed: { [weak self] in
                        if let strongSelf = self {
                            for currentRecord in strongSelf.holders {
                                if currentRecord.id == id {
                                    currentRecord.deactivatingDisposable = nil
                                    break
                                }
                            }
                            strongSelf.updateHolders()
                        }
                    })
                } else if activeIndex == nil {
                    let lastIndex = self.holders.count - 1
                    self.holders[lastIndex].active = true
                    self.applyType(self.holders[lastIndex].audioSessionType)
                    self.holders[lastIndex].activate()
                }
            }
        } else {
            self.applyType(.none)
        }
    }
    
    private func applyType(_ type: ManagedAudioSessionType) {
        if self.currentType != type {
            self.currentType = type
            
            do {
                if type != .none {
                    print("ManagedAudioSession setting category for \(type)")
                    try AVAudioSession.sharedInstance().setCategory(nativeCategoryForType(type))
                    print("ManagedAudioSession setting active \(type != .none)")
                    try AVAudioSession.sharedInstance().setActive(type != .none)
                } else {
                    print("ManagedAudioSession setting active false")
                    try AVAudioSession.sharedInstance().setActive(false)
                }
            } catch let error {
                print("ManagedAudioSession applyType error \(error)")
            }
            //[[AVAudioSession sharedInstance] setCategory:[self nativeCategoryForType:type] withOptions:(type == TGAudioSessionTypePlayAndRecord || type == TGAudioSessionTypePlayAndRecordHeadphones) ? AVAudioSessionCategoryOptionAllowBluetooth : 0 error:&error];
        }
    }
}
