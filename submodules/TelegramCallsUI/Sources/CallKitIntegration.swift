import Foundation
import UIKit
import CallKit
import Intents
import AVFoundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AppBundle

private var sharedProviderDelegate: AnyObject?

public final class CallKitIntegration {
    public static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #endif
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            return Locale.current.regionCode?.lowercased() != "cn"
        } else {
            return false
        }
    }
    
    private let audioSessionActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var audioSessionActive: Signal<Bool, NoError> {
        return self.audioSessionActivePromise.get()
    }
    
    init?(startCall: @escaping (Account, UUID, String) -> Signal<Bool, NoError>, answerCall: @escaping (UUID) -> Void, endCall: @escaping (UUID) -> Signal<Bool, NoError>, setCallMuted: @escaping (UUID, Bool) -> Void, audioSessionActivationChanged: @escaping (Bool) -> Void) {
        if !CallKitIntegration.isAvailable {
            return nil
        }
    
        #if targetEnvironment(simulator)
        return nil
        #else
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            if sharedProviderDelegate == nil {
                sharedProviderDelegate = CallKitProviderDelegate()
            }
            (sharedProviderDelegate as? CallKitProviderDelegate)?.setup(audioSessionActivePromise: self.audioSessionActivePromise, startCall: startCall, answerCall: answerCall, endCall: endCall, setCallMuted: setCallMuted, audioSessionActivationChanged: audioSessionActivationChanged)
        } else {
            return nil
        }
        #endif
    }
    
    func startCall(account: Account, peerId: PeerId, displayTitle: String) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            (sharedProviderDelegate as? CallKitProviderDelegate)?.startCall(account: account, peerId: peerId, displayTitle: displayTitle)
            self.donateIntent(peerId: peerId, displayTitle: displayTitle)
        }
    }
    
    func answerCall(uuid: UUID) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            (sharedProviderDelegate as? CallKitProviderDelegate)?.answerCall(uuid: uuid)
        }
    }
    
    func dropCall(uuid: UUID) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            (sharedProviderDelegate as? CallKitProviderDelegate)?.dropCall(uuid: uuid)
        }
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, displayTitle: String, completion: ((NSError?) -> Void)?) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            (sharedProviderDelegate as? CallKitProviderDelegate)?.reportIncomingCall(uuid: uuid, handle: handle, displayTitle: displayTitle, completion: completion)
        }
    }
    
    func reportOutgoingCallConnected(uuid: UUID, at date: Date) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            (sharedProviderDelegate as? CallKitProviderDelegate)?.reportOutgoingCallConnected(uuid: uuid, at: date)
        }
    }
    
    private func donateIntent(peerId: PeerId, displayTitle: String) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            let handle = INPersonHandle(value: "tg\(peerId.id)", type: .unknown)
            let contact = INPerson(personHandle: handle, nameComponents: nil, displayName: displayTitle, image: nil, contactIdentifier: nil, customIdentifier: "tg\(peerId.id)")
        
            let intent = INStartAudioCallIntent(contacts: [contact])
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .outgoing
            interaction.donate { _ in
            }
        }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
class CallKitProviderDelegate: NSObject, CXProviderDelegate {
    private let provider: CXProvider
    private let callController = CXCallController()
    
    private var currentStartCallAccount: (UUID, Account)?
    
    private var startCall: ((Account, UUID, String) -> Signal<Bool, NoError>)?
    private var answerCall: ((UUID) -> Void)?
    private var endCall: ((UUID) -> Signal<Bool, NoError>)?
    private var setCallMuted: ((UUID, Bool) -> Void)?
    private var audioSessionActivationChanged: ((Bool) -> Void)?
    
    private let disposableSet = DisposableSet()
    
    fileprivate var audioSessionActivePromise: ValuePromise<Bool>?
    
    override init() {
        self.provider = CXProvider(configuration: CallKitProviderDelegate.providerConfiguration)
        
        super.init()
        
        self.provider.setDelegate(self, queue: nil)
    }
    
    func setup(audioSessionActivePromise: ValuePromise<Bool>, startCall: @escaping (Account, UUID, String) -> Signal<Bool, NoError>, answerCall: @escaping (UUID) -> Void, endCall: @escaping (UUID) -> Signal<Bool, NoError>, setCallMuted: @escaping (UUID, Bool) -> Void, audioSessionActivationChanged: @escaping (Bool) -> Void) {
        self.audioSessionActivePromise = audioSessionActivePromise
        self.startCall = startCall
        self.answerCall = answerCall
        self.endCall = endCall
        self.setCallMuted = setCallMuted
        self.audioSessionActivationChanged = audioSessionActivationChanged
    }
    
    static var providerConfiguration: CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Telegram")
        
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber, .generic]
        if let image = UIImage(named: "Call/CallKitLogo", in: getAppBundle(), compatibleWith: nil) {
            providerConfiguration.iconTemplateImageData = image.pngData()
        }
        
        return providerConfiguration
    }
    
    private func requestTransaction(_ transaction: CXTransaction, completion: ((Bool) -> Void)? = nil) {
        self.callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            }
            completion?(error == nil)
        }
    }
    
    func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        self.requestTransaction(transaction)
    }
    
    func dropCall(uuid: UUID) {
        self.provider.reportCall(with: uuid, endedAt: nil, reason: CXCallEndedReason.remoteEnded)
    }
    
    func answerCall(uuid: UUID) {
        
    }
    
    func startCall(account: Account, peerId: PeerId, displayTitle: String) {
        let uuid = UUID()
        self.currentStartCallAccount = (uuid, account)
        let handle = CXHandle(type: .generic, value: "\(peerId.id)")
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.contactIdentifier = displayTitle

        startCallAction.isVideo = false
        let transaction = CXTransaction(action: startCallAction)
        
        self.requestTransaction(transaction, completion: { _ in
            let update = CXCallUpdate()
            update.remoteHandle = handle
            update.localizedCallerName = displayTitle
            update.supportsHolding = false
            update.supportsGrouping = false
            update.supportsUngrouping = false
            update.supportsDTMF = false
            
            self.provider.reportCall(with: uuid, updated: update)
        })
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, displayTitle: String, completion: ((NSError?) -> Void)?) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.localizedCallerName = displayTitle
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        
        self.provider.reportNewIncomingCall(with: uuid, update: update, completion: { error in
            completion?(error as NSError?)
        })
    }
    
    func reportOutgoingCallConnecting(uuid: UUID, at date: Date) {
        self.provider.reportOutgoingCall(with: uuid, startedConnectingAt: date)
    }
    
    func reportOutgoingCallConnected(uuid: UUID, at date: Date) {
        self.provider.reportOutgoingCall(with: uuid, connectedAt: date)
    }
    
    func providerDidReset(_ provider: CXProvider) {
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let startCall = self.startCall, let (uuid, account) = self.currentStartCallAccount, uuid == action.callUUID else {
            action.fail()
            return
        }
        self.currentStartCallAccount = nil
        let disposable = MetaDisposable()
        self.disposableSet.add(disposable)
        disposable.set((startCall(account, action.callUUID, action.handle.value)
        |> deliverOnMainQueue
        |> afterDisposed { [weak self, weak disposable] in
            if let strongSelf = self, let disposable = disposable {
                strongSelf.disposableSet.remove(disposable)
            }
        }).start(next: { result in
            if result {
                action.fulfill()
            } else {
                action.fail()
            }
        }))
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let answerCall = self.answerCall else {
            action.fail()
            return
        }
        answerCall(action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let endCall = self.endCall else {
            action.fail()
            return
        }
        let disposable = MetaDisposable()
        self.disposableSet.add(disposable)
        disposable.set((endCall(action.callUUID)
        |> deliverOnMainQueue
        |> afterDisposed { [weak self, weak disposable] in
            if let strongSelf = self, let disposable = disposable {
                strongSelf.disposableSet.remove(disposable)
            }
        }).start(next: { result in
            if result {
                action.fulfill(withDateEnded: Date())
            } else {
                action.fail()
            }
        }))
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let setCallMuted = self.setCallMuted else {
            action.fail()
            return
        }
        setCallMuted(action.uuid, action.isMuted)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        self.audioSessionActivationChanged?(true)
        self.audioSessionActivePromise?.set(true)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        self.audioSessionActivationChanged?(false)
        self.audioSessionActivePromise?.set(false)
    }
}

