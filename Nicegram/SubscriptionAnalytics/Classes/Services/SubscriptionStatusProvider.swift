//
//  SubscriptionStatusProvider.swift
//  MobySticker
//
//  Created by Vadim Suhodolskiy on 7/13/20.
//  Copyright © 2020 Mobyrix. All rights reserved.
//

import Foundation
final class SuscriptionStatusProvider {    
    static var hasActiveSubscription: Bool {
        if DataKeeper.isMigrationPerformed {
            if DataKeeper.cachedRenewableProducts.contains(where: { $0.status == .active || $0.status == .trial }) {
                // additional check
                if checkIfActiveProductsExpiry(products: DataKeeper.cachedRenewableProducts) {
                    return false
                } else {
                    return true
                }
            } else {
                return false
            }
        } else {
            return isSubscriptionExryDateValid
        }
    }
    
    private static var isSubscriptionExryDateValid: Bool {
        if let expiryDate = DataKeeper.subscriptionExpiryDate {
            return expiryDate > Date()
        } else {
            return false
        }
    }
    
    private static func checkIfActiveProductsExpiry(products: [RenewableProductDetails]) -> Bool {
        let activeProducts = products.filter { $0.status == .active || $0.status == .trial }
        return !activeProducts.contains(where: {
            if let date = $0.expiresDate {
                return date > Date()
            }
            return false
        })
    }
    
    private init() {}

}
