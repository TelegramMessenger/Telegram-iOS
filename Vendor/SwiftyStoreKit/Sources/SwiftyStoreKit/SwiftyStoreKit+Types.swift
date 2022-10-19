//
// SwiftyStoreKit+Types.swift
// SwiftyStoreKit
//
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import StoreKit

// MARK: Purchases

/// The Purchased protocol allows different purchase flows to be handled by common code in simple cases
/// 
/// For example you could route through to
///
///     func didPurchase<P:Purchased>(item:P) { ... }
///
/// for example
///  - SwiftyStoreKit.completeTransactions (in .purchased and .restored cases)
///  - SwiftyStoreKit.restorePurchases (for results.restoredPurchases)
///  - SwiftyStoreKit.purchaseProducd (in .success case)
public protocol Purchased {
    var productId: String { get }
    var quantity: Int { get }
    var originalPurchaseDate: Date { get }
}

extension Purchase: Purchased {
    public var originalPurchaseDate: Date {
        guard let date = originalTransaction?.transactionDate ?? transaction.transactionDate else {
            fatalError("there should always be a transaction date, so this should not happen...")
        }
        return  date
    }
}

extension PurchaseDetails: Purchased {
    public var originalPurchaseDate: Date {
        guard let date = originalTransaction?.transactionDate ?? transaction.transactionDate else {
            fatalError("there should always be a transaction date, so this should not happen...")
        }
        return  date
    }
}

// Restored product
public struct Purchase {
    public let productId: String
    public let quantity: Int
    public let transaction: PaymentTransaction
    public let originalTransaction: PaymentTransaction?
    public let needsFinishTransaction: Bool
    
    public init(productId: String, quantity: Int, transaction: PaymentTransaction, originalTransaction: PaymentTransaction?, needsFinishTransaction: Bool) {
        self.productId = productId
        self.quantity = quantity
        self.transaction = transaction
        self.originalTransaction = originalTransaction
        self.needsFinishTransaction = needsFinishTransaction
    }
}

/// Purchased product
public struct PurchaseDetails {
    public let productId: String
    public let quantity: Int
    public let product: SKProduct
    public let transaction: PaymentTransaction
    public let originalTransaction: PaymentTransaction?
    public let needsFinishTransaction: Bool
    
    public init(productId: String, quantity: Int, product: SKProduct, transaction: PaymentTransaction, originalTransaction: PaymentTransaction?, needsFinishTransaction: Bool) {
        self.productId = productId
        self.quantity = quantity
        self.product = product
        self.transaction = transaction
        self.originalTransaction = originalTransaction
        self.needsFinishTransaction = needsFinishTransaction
    }
}

/// Conform to this protocol to provide custom receipt validator
public protocol ReceiptValidator {
	func validate(receiptData: Data, completion: @escaping (VerifyReceiptResult) -> Void)
}

/// Payment transaction
public protocol PaymentTransaction {
    var transactionDate: Date? { get }
    var transactionState: SKPaymentTransactionState { get }
    var transactionIdentifier: String? { get }
    var downloads: [SKDownload] { get }
}

/// Add PaymentTransaction conformance to SKPaymentTransaction
extension SKPaymentTransaction: PaymentTransaction { }

/// Products information
public struct RetrieveResults {
    public let retrievedProducts: Set<SKProduct>
    public let invalidProductIDs: Set<String>
    public let error: Error?
    
    public init(retrievedProducts: Set<SKProduct>, invalidProductIDs: Set<String>, error: Error?) {
        self.retrievedProducts = retrievedProducts
        self.invalidProductIDs = invalidProductIDs
        self.error = error
    }
}

/// Purchase result
public enum PurchaseResult {
    case success(purchase: PurchaseDetails)
    case deferred(purchase: PurchaseDetails)
    case error(error: SKError)
}

/// Restore purchase results
public struct RestoreResults {
    public let restoredPurchases: [Purchase]
    public let restoreFailedPurchases: [(SKError, String?)]
    
    public init(restoredPurchases: [Purchase], restoreFailedPurchases: [(SKError, String?)]) {
        self.restoredPurchases = restoredPurchases
        self.restoreFailedPurchases = restoreFailedPurchases
    }
}

public typealias ShouldAddStorePaymentHandler = (_ payment: SKPayment, _ product: SKProduct) -> Bool
public typealias UpdatedDownloadsHandler = (_ downloads: [SKDownload]) -> Void

// MARK: Receipt verification

/// Info for receipt returned by server
public typealias ReceiptInfo = [String: AnyObject]

/// Fetch receipt result
public enum FetchReceiptResult {
    case success(receiptData: Data)
    case error(error: ReceiptError)
}

/// Verify receipt result
public enum VerifyReceiptResult {
    case success(receipt: ReceiptInfo)
    case error(error: ReceiptError)
}

/// Result for Consumable and NonConsumable
public enum VerifyPurchaseResult {
    case purchased(item: ReceiptItem)
    case notPurchased
}

/// Verify subscription result
public enum VerifySubscriptionResult {
    case purchased(expiryDate: Date, items: [ReceiptItem])
    case expired(expiryDate: Date, items: [ReceiptItem])
    case notPurchased
}

public enum SubscriptionType: Hashable {
    case autoRenewable
    case nonRenewing(validDuration: TimeInterval)
}

public struct ReceiptItem: Purchased, Codable {
    
    /// The product identifier of the item that was purchased. This value corresponds to the `productIdentifier` property of the `SKPayment` object stored in the transaction’s payment property.
    public var productId: String
    
    /// The number of items purchased. This value corresponds to the `quantity` property of the `SKPayment` object stored in the transaction’s payment property.
    public var quantity: Int
    
    /// The transaction identifier of the item that was purchased. This value corresponds to the transaction’s `transactionIdentifier` property.
    public var transactionId: String
    
    /// For a transaction that restores a previous transaction, the transaction identifier of the original transaction. 
    /// 
    /// Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s `transactionIdentifier` property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
    public var originalTransactionId: String
    
    /// The date and time that the item was purchased. This value corresponds to the transaction’s `transactionDate` property.
    public var purchaseDate: Date
    
    /// For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s `transactionDate` property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    public var originalPurchaseDate: Date
    
    /// The primary key for identifying subscription purchases.
    public var webOrderLineItemId: String?
    
    /// The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is **only** present for **auto-renewable** subscription receipts.
    public var subscriptionExpirationDate: Date?
    
    /// For a transaction that was canceled by Apple customer support, the time and date of the cancellation. 
    /// 
    /// Treat a canceled receipt the same as if no purchase had ever been made.
    public var cancellationDate: Date?
    
    /// Indicates whether or not the subscription item is currently within a given trial period.
    public var isTrialPeriod: Bool
    
    /// Indicates whether or not the subscription item is currently within an intro offer period.
    public var isInIntroOfferPeriod: Bool
    
    /// An indicator that a subscription has been canceled due to an upgrade. This field is only present for upgrade transactions.
    public var isUpgraded: Bool
    
    public init(productId: String, quantity: Int, transactionId: String, originalTransactionId: String, purchaseDate: Date, originalPurchaseDate: Date, webOrderLineItemId: String?, subscriptionExpirationDate: Date?, cancellationDate: Date?, isTrialPeriod: Bool, isInIntroOfferPeriod: Bool, isUpgraded: Bool) {
        self.productId = productId
        self.quantity = quantity
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.webOrderLineItemId = webOrderLineItemId
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.cancellationDate = cancellationDate
        self.isTrialPeriod = isTrialPeriod
        self.isInIntroOfferPeriod = isInIntroOfferPeriod
        self.isUpgraded = isUpgraded
    }
}

/// Error when managing receipt
public enum ReceiptError: Swift.Error {
    /// No receipt data
    case noReceiptData
    /// No data received
    case noRemoteData
    /// Error when encoding HTTP body into JSON
    case requestBodyEncodeError(error: Swift.Error)
    /// Error when proceeding request
    case networkError(error: Swift.Error)
    /// Error when decoding response
    case jsonDecodeError(string: String?)
    /// Receive invalid - bad status returned
    case receiptInvalid(receipt: ReceiptInfo, status: ReceiptStatus)
}

/// Status code returned by remote server
/// 
/// See Table 2-1  Status codes
public enum ReceiptStatus: Int {
    /// Not decodable status
    case unknown = -2
    /// No status returned
    case none = -1
    /// valid statua
    case valid = 0
    /// The App Store could not read the JSON object you provided.
    case jsonNotReadable = 21000
    /// The data in the receipt-data property was malformed or missing.
    case malformedOrMissingData = 21002
    /// The receipt could not be authenticated.
    case receiptCouldNotBeAuthenticated = 21003
    /// The shared secret you provided does not match the shared secret on file for your account.
    case secretNotMatching = 21004
    /// The receipt server is not currently available.
    case receiptServerUnavailable = 21005
    /// This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.
    case subscriptionExpired = 21006
    ///  This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
    case testReceipt = 21007
    /// This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.
    case productionEnvironment = 21008

    var isValid: Bool { return self == .valid}
}

// Receipt field as defined in : https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1
public enum ReceiptInfoField: String {
    /// Bundle Identifier. This corresponds to the value of CFBundleIdentifier in the Info.plist file.
    case bundle_id
    /// The app’s version number.This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
    case application_version
    /// The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made.
    case original_application_version
    /// The date when the app receipt was created.
    case creation_date
    /// The date that the app receipt expires. This key is present only for apps purchased through the Volume Purchase Program.
    case expiration_date

    /// The receipt for an in-app purchase.
    case in_app

    public enum InApp: String {
        /// The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
        case quantity
        /// The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
        case product_id
        /// The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
        case transaction_id
        /// For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
        case original_transaction_id
        /// The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
        case purchase_date
        /// For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
        case original_purchase_date
        /// The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.
        case expires_date
        /// For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.
        case cancellation_date
        #if os(iOS) || os(tvOS)
        /// A string that the App Store uses to uniquely identify the application that created the transaction. If your server supports multiple applications, you can use this value to differentiate between them. Apps are assigned an identifier only in the production environment, so this key is not present for receipts created in the test environment. This field is not present for Mac apps. See also Bundle Identifier.
        case app_item_id
        #endif
        /// An arbitrary number that uniquely identifies a revision of your application. This key is not present for receipts created in the test environment.
        case version_external_identifier
        /// The primary key for identifying subscription purchases.
        case web_order_line_item_id
    }
}

#if os(OSX)
    public enum ReceiptExitCode: Int32 {
        /// If validation fails in OS X, call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
        case notValid = 173
    }
#endif
