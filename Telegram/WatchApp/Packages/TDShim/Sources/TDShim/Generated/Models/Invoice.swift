//
//  Invoice.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Product invoice
public struct Invoice: Codable, Equatable, Hashable {

    /// ISO 4217 currency code
    public let currency: String

    /// True, if the total price depends on the shipping method
    public let isFlexible: Bool

    /// True, if the payment is a test payment
    public let isTest: Bool

    /// The maximum allowed amount of tip in the smallest units of the currency
    public let maxTipAmount: Int64

    /// True, if the user's email address is needed for payment
    public let needEmailAddress: Bool

    /// True, if the user's name is needed for payment
    public let needName: Bool

    /// True, if the user's phone number is needed for payment
    public let needPhoneNumber: Bool

    /// True, if the user's shipping address is needed for payment
    public let needShippingAddress: Bool

    /// A list of objects used to calculate the total price of the product
    public let priceParts: [LabeledPricePart]

    /// An HTTP URL with terms of service for recurring payments. If non-empty, the invoice payment will result in recurring payments and the user must accept the terms of service before allowed to pay
    public let recurringPaymentTermsOfServiceUrl: String

    /// True, if the user's email address will be sent to the provider
    public let sendEmailAddressToProvider: Bool

    /// True, if the user's phone number will be sent to the provider
    public let sendPhoneNumberToProvider: Bool

    /// The number of seconds between consecutive Telegram Star debiting for subscription invoices; 0 if the invoice doesn't create subscription
    public let subscriptionPeriod: Int

    /// Suggested amounts of tip in the smallest units of the currency
    public let suggestedTipAmounts: [Int64]

    /// An HTTP URL with terms of service for non-recurring payments. If non-empty, then the user must accept the terms of service before allowed to pay
    public let termsOfServiceUrl: String


    public init(
        currency: String,
        isFlexible: Bool,
        isTest: Bool,
        maxTipAmount: Int64,
        needEmailAddress: Bool,
        needName: Bool,
        needPhoneNumber: Bool,
        needShippingAddress: Bool,
        priceParts: [LabeledPricePart],
        recurringPaymentTermsOfServiceUrl: String,
        sendEmailAddressToProvider: Bool,
        sendPhoneNumberToProvider: Bool,
        subscriptionPeriod: Int,
        suggestedTipAmounts: [Int64],
        termsOfServiceUrl: String
    ) {
        self.currency = currency
        self.isFlexible = isFlexible
        self.isTest = isTest
        self.maxTipAmount = maxTipAmount
        self.needEmailAddress = needEmailAddress
        self.needName = needName
        self.needPhoneNumber = needPhoneNumber
        self.needShippingAddress = needShippingAddress
        self.priceParts = priceParts
        self.recurringPaymentTermsOfServiceUrl = recurringPaymentTermsOfServiceUrl
        self.sendEmailAddressToProvider = sendEmailAddressToProvider
        self.sendPhoneNumberToProvider = sendPhoneNumberToProvider
        self.subscriptionPeriod = subscriptionPeriod
        self.suggestedTipAmounts = suggestedTipAmounts
        self.termsOfServiceUrl = termsOfServiceUrl
    }
}

