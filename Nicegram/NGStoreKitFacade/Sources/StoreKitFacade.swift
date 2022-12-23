import Foundation
import StoreKit
import SwiftyStoreKit

public enum StoreKitPurchaseResult {
    case success(receiptData: Data, finishTransaction: () -> Void)
    case cancelled
    case error(Error)
}

public enum StoreKitReceiptResult {
    case success(receiptData: Data)
    case error(Error)
}

public struct TransactionToComplete {
    public let productId: String
    public let finishTransaction: () -> Void
}

public class StoreKitFacade {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func purchase(productId: String, completion: @escaping (StoreKitPurchaseResult) -> Void) {
        SwiftyStoreKit.purchaseProduct(productId, atomically: false) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let product):
                self.fetchReceipt(forceRefresh: false) { result in
                    switch result {
                    case .success(let receiptData):
                        let finishTransaction: () -> Void = {
                            SwiftyStoreKit.finishTransaction(product.transaction)
                        }
                        completion(.success(receiptData: receiptData, finishTransaction: finishTransaction))
                    case .failure(let error):
                        completion(.error(error))
                    }
                }
            case .error(let error):
                if error.code == .paymentCancelled {
                    completion(.cancelled)
                } else {
                    completion(.error(error))
                }
            case .deferred(_):
                completion(.cancelled)
            }
        }
    }
    
    public func fetchReceipt(forceRefresh: Bool, completion: @escaping (Result<Data, Error>) -> ()) {
        SwiftyStoreKit.fetchReceipt(forceRefresh: forceRefresh) { result in
            switch result {
            case .success(let receiptData):
                completion(.success(receiptData))
            case .error(let error):
                if let localReceipt = SwiftyStoreKit.localReceiptData {
                    completion(.success(localReceipt))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func completeTransactions(completion: @escaping ([TransactionToComplete]) -> Void) {
        SwiftyStoreKit.completeTransactions(atomically: false) { purchases in
            let transactionsToComplete = purchases.map { purchase in
                return TransactionToComplete(productId: purchase.productId) {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
            
            completion(transactionsToComplete)
        }
    }
}
