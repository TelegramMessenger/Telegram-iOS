import Foundation
import CloudKit
import MtProtoKit
import SwiftSignalKit
import EncryptionProvider

private enum FetchError {
    case generic
    case networkUnavailable
}

@available(iOS 10.0, *)
private func fetchRawData(prefix: String) -> Signal<Data, FetchError> {
    return Signal { subscriber in
        #if targetEnvironment(simulator)
        return EmptyDisposable
        #else
        let container = CKContainer.default()
        let publicDatabase = container.database(with: .public)
        let recordId = CKRecord.ID(recordName: "emergency-datacenter-\(prefix)")
        publicDatabase.fetch(withRecordID: recordId, completionHandler: { record, error in
            if let error = error {
                print("publicDatabase.fetch error: \(error)")
                let nsError = error as NSError
                if nsError.domain == CKError.errorDomain, nsError.code == 1 {
                    subscriber.putError(.networkUnavailable)
                } else {
                    subscriber.putError(.generic)
                }
            } else if let record = record {
                guard let dataString = record.object(forKey: "data") as? String else {
                    subscriber.putError(.generic)
                    return
                }
                guard let data = Data(base64Encoded: dataString, options: [.ignoreUnknownCharacters]) else {
                    subscriber.putError(.generic)
                    return
                }
                var resultData = data
                resultData.count = 256
                subscriber.putNext(resultData)
                subscriber.putCompletion()
            } else {
                subscriber.putError(.generic)
            }
        })
        
        return ActionDisposable {
        }
        #endif
    }
}

@available(iOS 10.0, *)
private final class CloudDataPrefixContext {
    private let prefix: String
    private let value = Promise<Data?>()
    
    private var lastRequestTimestamp: Double?
    
    init(prefix: String) {
        self.prefix = prefix
    }
    
    private func fetch() {
        let fetchSignal = (
            fetchRawData(prefix: self.prefix)
            |> map(Optional.init)
            |> `catch` { error -> Signal<Data?, NoError> in
                switch error {
                case .networkUnavailable:
                    return .complete()
                default:
                    return .single(nil)
                }
            }
            |> restart
        )
        |> take(1)
        self.value.set(fetchSignal)
    }
    
    func get() -> Signal<Data?, NoError> {
        var shouldFetch = false
        let timestamp = CFAbsoluteTimeGetCurrent()
        if let lastRequestTimestamp = self.lastRequestTimestamp {
            shouldFetch = timestamp >= lastRequestTimestamp + 1.0 * 60.0
        } else {
            shouldFetch = true
        }
        if shouldFetch {
            self.lastRequestTimestamp = timestamp
            self.fetch()
        }
        return self.value.get()
    }
}

@available(iOS 10.0, *)
private final class CloudDataContextObject {
    private let queue: Queue
    
    private var prefixContexts: [String: CloudDataPrefixContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    func get(prefix: String) -> Signal<Data?, NoError> {
        let context: CloudDataPrefixContext
        if let current = self.prefixContexts[prefix] {
            context = current
        } else {
            context = CloudDataPrefixContext(prefix: prefix)
        }
        return context.get()
    }
}

public protocol CloudDataContext {
    func get(phoneNumber: Signal<String?, NoError>) -> Signal<MTBackupDatacenterData, NoError>
}

@available(iOS 10.0, *)
public final class CloudDataContextImpl: CloudDataContext {
    private let queue = Queue()
    private let encryptionProvider: EncryptionProvider
    private let impl: QueueLocalObject<CloudDataContextObject>
    
    public init(encryptionProvider: EncryptionProvider) {
        self.encryptionProvider = encryptionProvider
        
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return CloudDataContextObject(queue: queue)
        })
    }
    
    public func get(phoneNumber: Signal<String?, NoError>) -> Signal<MTBackupDatacenterData, NoError> {
        let encryptionProvider = self.encryptionProvider
        return phoneNumber
        |> take(1)
        |> mapToSignal { phoneNumber -> Signal<MTBackupDatacenterData, NoError> in
            var prefix = ""
            if let phoneNumber = phoneNumber, phoneNumber.count >= 1 {
                prefix = String(phoneNumber[phoneNumber.startIndex ..< phoneNumber.index(after: phoneNumber.startIndex)])
            }
            return Signal { subscriber in
                let disposable = MetaDisposable()
                self.impl.with { impl in
                    disposable.set(impl.get(prefix: prefix).start(next: { data in
                        if let data = data, let datacenterData = MTIPDataDecode(encryptionProvider, data, phoneNumber ?? "") {
                            subscriber.putNext(datacenterData)
                            subscriber.putCompletion()
                        } else {
                            subscriber.putCompletion()
                        }
                    }))
                }
                return disposable
            }
        }
    }
}
