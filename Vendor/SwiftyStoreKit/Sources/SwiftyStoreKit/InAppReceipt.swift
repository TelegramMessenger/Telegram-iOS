//
//  InAppReceipt.swift
//  SwiftyStoreKit
//
//  Created by phimage on 22/12/15.
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

import Foundation

extension Date {

    init?(millisecondsSince1970: String) {
        guard let millisecondsNumber = Double(millisecondsSince1970) else {
            return nil
        }
        self = Date(timeIntervalSince1970: millisecondsNumber / 1000)
    }
}

extension ReceiptItem {

    public init?(receiptInfo: ReceiptInfo) {
        guard
            let productId = receiptInfo["product_id"] as? String,
            let quantityString = receiptInfo["quantity"] as? String,
            let quantity = Int(quantityString),
            let transactionId = receiptInfo["transaction_id"] as? String,
            let originalTransactionId = receiptInfo["original_transaction_id"] as? String,
            let purchaseDate = ReceiptItem.parseDate(from: receiptInfo, key: "purchase_date_ms"),
            let originalPurchaseDate = ReceiptItem.parseDate(from: receiptInfo, key: "original_purchase_date_ms")
            else {
                print("could not parse receipt item: \(receiptInfo). Skipping...")
                return nil
        }
        self.productId = productId
        self.quantity = quantity
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.webOrderLineItemId = receiptInfo["web_order_line_item_id"] as? String
        self.subscriptionExpirationDate = ReceiptItem.parseDate(from: receiptInfo, key: "expires_date_ms")
        self.cancellationDate = ReceiptItem.parseDate(from: receiptInfo, key: "cancellation_date_ms")
        if let isTrialPeriod = receiptInfo["is_trial_period"] as? String {
            self.isTrialPeriod = Bool(isTrialPeriod) ?? false
        } else {
            self.isTrialPeriod = false
        }
        if let isInIntroOfferPeriod = receiptInfo["is_in_intro_offer_period"] as? String {
            self.isInIntroOfferPeriod = Bool(isInIntroOfferPeriod) ?? false
        } else {
            self.isInIntroOfferPeriod = false
        }
        self.isUpgraded = receiptInfo["is_upgraded"] as? Bool ?? false
    }

    private static func parseDate(from receiptInfo: ReceiptInfo, key: String) -> Date? {

        guard
            let requestDateString = receiptInfo[key] as? String,
            let requestDateMs = Double(requestDateString) else {
                return nil
        }
        return Date(timeIntervalSince1970: requestDateMs / 1000)
    }
}

// MARK: - receipt mangement
internal class InAppReceipt {

    /**
     *  Verify the purchase of a Consumable or NonConsumable product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the purchase
     *  - return: either notPurchased or purchased
     */
    class func verifyPurchase(
        productId: String,
        inReceipt receipt: ReceiptInfo
    ) -> VerifyPurchaseResult {

        // Get receipts info for the product
        let receipts = getInAppReceipts(receipt: receipt)
        let filteredReceiptsInfo = filterReceiptsInfo(receipts: receipts, withProductIds: [productId])
        let nonCancelledReceiptsInfo = filteredReceiptsInfo.filter { receipt in receipt["cancellation_date"] == nil }

        #if swift(>=4.1)
            let receiptItems = nonCancelledReceiptsInfo.compactMap { ReceiptItem(receiptInfo: $0) }
        #else
            let receiptItems = nonCancelledReceiptsInfo.flatMap { ReceiptItem(receiptInfo: $0) }
        #endif
        
        // Verify that at least one receipt has the right product id
        if let firstItem = receiptItems.first {
            return .purchased(item: firstItem)
        }
        return .notPurchased
    }

    /**
     *  Verify the validity of a set of subscriptions in a receipt.
     *
     *  This method extracts all transactions matching the given productIds and sorts them by date in descending order. It then compares the first transaction expiry date against the receipt date, to determine its validity.
     *  - Note: You can use this method to check the validity of (mutually exclusive) subscriptions in a subscription group.
     *  - Remark: The type parameter determines how the expiration dates are calculated for all subscriptions. Make sure all productIds match the specified subscription type to avoid incorrect results.
     *  - Parameter type: .autoRenewable or .nonRenewing.
     *  - Parameter productIds: The product ids of the subscriptions to verify.
     *  - Parameter receipt: The receipt to use for looking up the subscriptions
     *  - Parameter validUntil: Date to check against the expiry date of the subscriptions. This is only used if a date is not found in the receipt.
     *  - return: Either .notPurchased or .purchased / .expired with the expiry date found in the receipt.
     */
    class func verifySubscriptions(
        ofType type: SubscriptionType,
        productIds: Set<String>,
        inReceipt receipt: ReceiptInfo,
        validUntil date: Date = Date()
    ) -> VerifySubscriptionResult {

        // The values of the latest_receipt and latest_receipt_info keys are useful when checking whether an auto-renewable subscription is currently active. By providing any transaction receipt for the subscription and checking these values, you can get information about the currently-active subscription period. If the receipt being validated is for the latest renewal, the value for latest_receipt is the same as receipt-data (in the request) and the value for latest_receipt_info is the same as receipt.
        let (receipts, duration) = getReceiptsAndDuration(for: type, inReceipt: receipt)
        let receiptsInfo = filterReceiptsInfo(receipts: receipts, withProductIds: productIds)
        let nonCancelledReceiptsInfo = receiptsInfo.filter { receipt in receipt["cancellation_date"] == nil }
        if nonCancelledReceiptsInfo.count == 0 {
            return .notPurchased
        }

        let receiptDate = getReceiptRequestDate(inReceipt: receipt) ?? date

        #if swift(>=4.1)
            let receiptItems = nonCancelledReceiptsInfo.compactMap { ReceiptItem(receiptInfo: $0) }
        #else
            let receiptItems = nonCancelledReceiptsInfo.flatMap { ReceiptItem(receiptInfo: $0) }
        #endif

        if nonCancelledReceiptsInfo.count > receiptItems.count {
            print("receipt has \(nonCancelledReceiptsInfo.count) items, but only \(receiptItems.count) were parsed")
        }

        let sortedExpiryDatesAndItems = expiryDatesAndItems(receiptItems: receiptItems, duration: duration).sorted { a, b in
            return a.0 > b.0
        }

        guard let firstExpiryDateItemPair = sortedExpiryDatesAndItems.first else {
            return .notPurchased
        }

        let sortedReceiptItems = sortedExpiryDatesAndItems.map { $0.1 }
        if firstExpiryDateItemPair.0 > receiptDate {
            return .purchased(expiryDate: firstExpiryDateItemPair.0, items: sortedReceiptItems)
        } else {
            return .expired(expiryDate: firstExpiryDateItemPair.0, items: sortedReceiptItems)
        }
    }
    
    /**
     *  Get the distinct product identifiers from receipt.
     *
     *  This Method extracts all product identifiers. (Including cancelled ones).
     *  - Note: You can use this method to get all unique product identifiers from receipt.
     *  - Parameter type: .autoRenewable or .nonRenewing.
     *  - Parameter receipt: The receipt to use for looking up the product identifiers.
     *  - return: Either Set<String> or nil.
     */
    class func getDistinctPurchaseIds(
        ofType type: SubscriptionType,
        inReceipt receipt: ReceiptInfo
    ) -> Set<String>? {
        
        // Get receipts array from receipt
        guard let receipts = getReceipts(for: type, inReceipt: receipt) else {
            return nil
        }
        
        #if swift(>=4.1)
            let receiptIds = receipts.compactMap { ReceiptItem(receiptInfo: $0)?.productId }
        #else
            let receiptIds = receipts.flatMap { ReceiptItem(receiptInfo: $0)?.productId }
        #endif
        
        if receiptIds.isEmpty {
            return nil
        }
        
        return Set(receiptIds)
    }

    private class func expiryDatesAndItems(receiptItems: [ReceiptItem], duration: TimeInterval?) -> [(Date, ReceiptItem)] {

        if let duration = duration {
            return receiptItems.map {
                let expirationDate = Date(timeIntervalSince1970: $0.originalPurchaseDate.timeIntervalSince1970 + duration)
                return (expirationDate, $0)
            }
        } else {
            #if swift(>=4.1)
                return receiptItems.compactMap {
                    if let expirationDate = $0.subscriptionExpirationDate {
                        return (expirationDate, $0)
                    }
                    return nil
                }
            #else
                return receiptItems.flatMap {
                    if let expirationDate = $0.subscriptionExpirationDate {
                        return (expirationDate, $0)
                    }
                    return nil
                }
            #endif
        }
    }
    
    private class func getReceipts(for subscriptionType: SubscriptionType, inReceipt receipt: ReceiptInfo) -> [ReceiptInfo]? {
        switch subscriptionType {
        case .autoRenewable:
            return receipt["latest_receipt_info"] as? [ReceiptInfo]
        case .nonRenewing:
            return getInAppReceipts(receipt: receipt)
        }
    }

    private class func getReceiptsAndDuration(for subscriptionType: SubscriptionType, inReceipt receipt: ReceiptInfo) -> ([ReceiptInfo]?, TimeInterval?) {
        switch subscriptionType {
        case .autoRenewable:
            return (receipt["latest_receipt_info"] as? [ReceiptInfo], nil)
        case .nonRenewing(let duration):
            return (getInAppReceipts(receipt: receipt), duration)
        }
    }

    private class func getReceiptRequestDate(inReceipt receipt: ReceiptInfo) -> Date? {

        guard let receiptInfo = receipt["receipt"] as? ReceiptInfo,
            let requestDateString = receiptInfo["request_date_ms"] as? String else {
            return nil
        }
        return Date(millisecondsSince1970: requestDateString)
    }
    
    private class func getInAppReceipts(receipt: ReceiptInfo) -> [ReceiptInfo]? {
        
        let appReceipt = receipt["receipt"] as? ReceiptInfo
        return appReceipt?["in_app"] as? [ReceiptInfo]
    }

    /**
     *  Get all the receipts info for a specific product
     *  - Parameter receipts: the receipts array to grab info from
     *  - Parameter productId: the product id
     */
    private class func filterReceiptsInfo(receipts: [ReceiptInfo]?, withProductIds productIds: Set<String>) -> [ReceiptInfo] {

        guard let receipts = receipts else {
            return []
        }

        // Filter receipts with matching product ids
        let receiptsMatchingProductIds = receipts
            .filter { (receipt) -> Bool in
                if let productId = receipt["product_id"] as? String {
                    return productIds.contains(productId)
                }
                return false
            }

        return receiptsMatchingProductIds
    }
}
