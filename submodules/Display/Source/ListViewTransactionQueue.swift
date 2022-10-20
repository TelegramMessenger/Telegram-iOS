import Foundation
import UIKit
import SwiftSignalKit

public typealias ListViewTransaction = (@escaping () -> Void) -> Void

public final class ListViewTransactionQueue {
    private var transactions: [ListViewTransaction] = []
    public final var transactionCompleted: () -> Void = { }
    
    public init() {
    }
    
    public func addTransaction(_ transaction: @escaping ListViewTransaction) {
        precondition(Thread.isMainThread)
        let beginTransaction = self.transactions.count == 0
        self.transactions.append(transaction)
        
        if beginTransaction {
            transaction({ [weak self] in
                precondition(Thread.isMainThread)
                
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
        } else {
            assert(true)
        }
    }
    
    private func endTransaction() {
        precondition(Thread.isMainThread)
        Queue.mainQueue().async {
            self.transactionCompleted()
            if !self.transactions.isEmpty {
                let _ = self.transactions.removeFirst()
            }
            
            if let nextTransaction = self.transactions.first {
                nextTransaction({ [weak self] in
                    precondition(Thread.isMainThread)
                    
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
