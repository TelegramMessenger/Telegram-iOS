//
//  ProductsInfoResult.swift
//  SubscriptionAnalytics
//
//  Created by Vadim Suhodolskiy on 8/7/20.
//

import Foundation

public struct ProductsInfoResult: Codable {
    public let transactions: [RenewableProductDetails]
}
