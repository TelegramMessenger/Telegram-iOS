//
//  Subscription.swift
//  AirTranslator
//
//  Created by Vadim Suhodolskiy on 2/24/21.
//

import Foundation
import StoreKit
import NGIAP

// MARK: - Subscription Duration Type

public enum SubscriptionDuration: Int {
    case month

    @available(iOS 11.2, *)
    init?(period: SKProductSubscriptionPeriod?) {
        guard let period = period else {
            return nil
        }

        switch (period.unit, period.numberOfUnits) {
        case (.month, _):
            self = .month
        default:
            return nil
        }
    }
}

// MARK: - Subscription

public struct Subscription {

    // MARK: - Properties

    public let identifier: String

    public let price: String

    public let subscriptionDuration: SubscriptionDuration?

    public let product: SKProduct?

    // MARK: - Object life cycle

    init(product: SKProduct) {
        self.product = product
        self.identifier = product.productIdentifier
        self.price = product.localizedPrice ?? ""

        if #available(iOS 11.2, *) {
            self.subscriptionDuration = SubscriptionDuration(period: product.subscriptionPeriod)
        } else {
            self.subscriptionDuration = Subscription.cachedPeriod(for: product.productIdentifier)
        }
    }

    public init(
        identifier: String,
        price: String,
        subscriptionDuration: SubscriptionDuration?
    ) {
        self.identifier = identifier
        self.price = price
        self.subscriptionDuration = subscriptionDuration
        self.product = nil
    }
}

// MARK: - Default values

public extension Subscription {
    static var subscriptions: [Subscription] = [
        Subscription(
            identifier: NicegramProducts.Premium,
            price: "$1.99",
            subscriptionDuration: .month
        ),
    ]

    static func cachedPriceNumberValue(for productIdentifier: String) -> Double? {
        return 1.99
    }

    static func cachedCurrencySymbol(for productIdentifier: String) -> String? {
        return "$"
    }

    static func cachedPeriod(for productIdentifier: String) -> SubscriptionDuration? {
        return .month
    }
}

