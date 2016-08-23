import Foundation
import SwiftSignalKit

public typealias ListViewTransaction = @escaping (@escaping (Void) -> Void) -> Void

public final class ListViewTransactionQueue {
    private var transactions: [ListViewTransaction] = []
    public final var transactionCompleted: (Void) -> Void = { }
    
    public init() {
    }
    
    public func addTransaction(_ transaction: ListViewTransaction) {
        let beginTransaction = self.transactions.count == 0
        self.transactions.append(transaction)
        
        if beginTransaction {
            transaction({ [weak self] in
                if Thread.isMainThread {
                    if let strongSelf = self {
                        strongSelf.endTransaction()
                    }
                } else {
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.endTransaction()
                        }
                    }
                }
            })
        }
    }
    
    private func endTransaction() {
        Queue.mainQueue().async {
            self.transactionCompleted()
            let _ = self.transactions.removeFirst()
            
            if let nextTransaction = self.transactions.first {
                nextTransaction({ [weak self] in
                    if Thread.isMainThread {
                        if let strongSelf = self {
                            strongSelf.endTransaction()
                        }
                    } else {
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.endTransaction()
                            }
                        }
                    }
                })
            }
        }
    }
}
