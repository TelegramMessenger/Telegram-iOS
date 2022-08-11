//
//  ReneableProductsDetails + firstActiveProduct.swift
//  Pods-SubscriptionAnalytics_Tests
//
//  Created by Vadim Suhodolskiy on 7/17/20.
//

import Foundation

public extension Array where Element == RenewableProductDetails {
    var firstActiveProduct: RenewableProductDetails? {
        return self.first(where: { [RenewableProductDetails.Status.active, .trial].contains($0.status) })
    }
}
