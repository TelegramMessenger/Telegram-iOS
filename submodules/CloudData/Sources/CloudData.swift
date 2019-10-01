import Foundation
import CloudKit
import MtProtoKit
import SwiftSignalKit

private enum FetchError {
    case generic
    case networkUnavailable
}

@available(iOS 10.0, *)
private func fetchRawData(prefix: String) -> Signal<Data, FetchError> {
    return Signal { subscriber in
        let container = CKContainer.default()
        let publicDatabase = container.database(with: .public)
        let recordId = CKRecord.ID(recordName: "emergency-datacenter-\(prefix)")
        publicDatabase.fetch(withRecordID: recordId, completionHandler: { record, error in
            if let error = error {
                print("publicDatabase.fetch error: \(error)")
                if let error = error as? NSError, error.domain == CKError.errorDomain, error.code == 1 {
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
    }
}

@available(iOS 10.0, *)
public func cloudDataAdditionalAddressSource(phoneNumber: Signal<String?, NoError>) -> Signal<MTBackupDatacenterData, NoError> {
    return phoneNumber
    |> take(1)
    |> mapToSignal { _ -> Signal<MTBackupDatacenterData, NoError> in
        let phoneNumber: String? = "7950"
        var prefix = ""
        if let phoneNumber = phoneNumber, phoneNumber.count >= 1 {
            prefix = String(phoneNumber[phoneNumber.startIndex ..< phoneNumber.index(after: phoneNumber.startIndex)])
        }
        return fetchRawData(prefix: prefix)
        |> map { data -> MTBackupDatacenterData? in
            if let datacenterData = MTIPDataDecode(data, phoneNumber ?? "") {
                return datacenterData
            } else {
                return nil
            }
        }
        |> `catch` { error -> Signal<MTBackupDatacenterData?, NoError> in
            return .complete()
        }
        |> mapToSignal { data -> Signal<MTBackupDatacenterData, NoError> in
            if let data = data {
                return .single(data)
            } else {
                return .complete()
            }
        }
    }
}

@available(iOS 10.0, *)
private final class CloudDataContextObject {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        let container = CKContainer.default()
        let publicDatabase = container.database(with: .public)
        
        /*let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
        changesOperation.fetchAllChanges = true
        changesOperation.recordZoneWithIDChangedBlock = { _ in
            print("recordZoneWithIDChangedBlock")
        }
        changesOperation.recordZoneWithIDWasDeletedBlock = { _ in
            
        }
        changesOperation.changeTokenUpdatedBlock = { _ in
            print("changeTokenUpdatedBlock")
        }
        changesOperation.fetchDatabaseChangesCompletionBlock = { serverChangeToken, isMoreComing, error in
            print("done")
        }
        publicDatabase.add(changesOperation)*/
    }
}

public protocol CloudDataContext {
    
}

@available(iOS 10.0, *)
public final class CloudDataContextImpl: CloudDataContext {
    private let queue = Queue()
    private let impl: QueueLocalObject<CloudDataContextObject>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return CloudDataContextObject(queue: queue)
        })
    }
}
