import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

private final class DocumentContext {
    private let disposable: Disposable
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
    
    deinit {
        self.disposable.dispose()
    }
}

final class SecureIdVerificationDocumentsContext {
    private let context: SecureIdAccessContext
    private let postbox: Postbox
    private let network: Network
    private let update: (Int64, SecureIdVerificationLocalDocumentState) -> Void
    private var contexts: [Int64: DocumentContext] = [:]
    private(set) var uploadedFiles: [Data: Data] = [:]
    
    init(postbox: Postbox, network: Network, context: SecureIdAccessContext, update: @escaping (Int64, SecureIdVerificationLocalDocumentState) -> Void) {
        self.postbox = postbox
        self.network = network
        self.context = context
        self.update = update
    }
    
    func stateUpdated(_ documents: [SecureIdVerificationDocument]) {
        var validIds = Set<Int64>()
        
        for document in documents {
            switch document {
                case let .local(info):
                    validIds.insert(info.id)
                    if self.contexts[info.id] == nil {
                        let disposable = MetaDisposable()
                        self.contexts[info.id] = DocumentContext(disposable: disposable)
                        disposable.set((uploadSecureIdFile(context: self.context, postbox: self.postbox, network: self.network, resource: info.resource)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            if let strongSelf = self {
                                switch result {
                                    case let .progress(value):
                                        if strongSelf.contexts[info.id] != nil {
                                            strongSelf.update(info.id, .uploading(value))
                                        }
                                    case let .result(file, data):
                                        if strongSelf.contexts[info.id] != nil {
                                           strongSelf.uploadedFiles[file.fileHash] = data
                                            strongSelf.update(info.id, .uploaded(file))
                                        }
                                }
                            }
                        }, error: { _ in
                        }))
                    }
                case .remote:
                    break
            }
        }
        
        var removeIds: [Int64] = []
        for (id, _) in self.contexts {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            self.contexts.removeValue(forKey: id)
        }
    }
}
