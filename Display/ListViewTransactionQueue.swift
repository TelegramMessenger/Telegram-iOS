import Foundation
#if os(iOS)
import SwiftSignalKit
#else
import SwiftSignalKitMac
#endif

public typealias ListViewTransaction = (@escaping () -> Void) -> Void

public final class ListViewTransactionQueue {
    private var transactions: [ListViewTransaction] = []
    public final var transactionCompleted: () -> Void = { }
    
    public init() {
    }
    
    public func addTransaction(_ transaction: @escaping ListViewTransaction) {
        assert(Thread.isMainThread)
        let beginTransaction = self.transactions.count == 0
        self.transactions.append(transaction)
        
        if beginTransaction {
            transaction({ [weak self] in
                assert(Thread.isMainThread)
                
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
        assert(Thread.isMainThread)
        Queue.mainQueue().async {
            self.transactionCompleted()
            if !self.transactions.isEmpty {
                let _ = self.transactions.removeFirst()
            }
            
            if let nextTransaction = self.transactions.first {
                nextTransaction({ [weak self] in
                    assert(Thread.isMainThread)
                    
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
