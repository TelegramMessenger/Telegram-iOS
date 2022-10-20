//
//  RenewableProductDetails.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/9/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

// MARK: - RenewableProductDetails

public struct RenewableProductDetails: Codable {
    
    // MARK: - Properties
    
    public let transactionID: Int
    public let productID: String
    public let environment: Enviroment
    public let status: Status
    public let expiresDate: Date?
    private let expiresDateTimestamp: Int64?
    private let isActive: Bool
    private let isTrial: Bool
    
    // MARK: - Object life cycle
    
    init(transactionID: Int,
        productID: String,
        environment: Enviroment,
        status: Status,
        expiresDate: Date?) {
        self.transactionID = transactionID
        self.productID = productID
        self.environment = environment
        self.status = status
        self.expiresDate = expiresDate
        
        switch status {
        case .active:
            self.isActive = true
            self.isTrial = false
            
        case .trial:
            self.isTrial = true
            self.isActive = true
        
        default:
            self.isActive = false
            self.isTrial = false
        }
        
        if let date = expiresDate {
            self.expiresDateTimestamp = Int64(date.timeIntervalSince1970 * 1000)
        } else {
            self.expiresDateTimestamp = nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        productID = try container.decode(String.self, forKey: .productID)
        environment = try container.decode(Enviroment.self, forKey: .environment)
        expiresDateTimestamp = try? container.decode(Int64.self, forKey: .expiresDateTimestamp)
        transactionID = try container.decode(Int.self, forKey: .transactionID)
        let isActive = try container.decode(Bool.self, forKey: .isActive)
        let isTrial = try container.decode(Bool.self, forKey: .isTrial)
        
        self.isActive = isActive
        self.isTrial = isTrial
        
        if let timeStamp = expiresDateTimestamp {
            self.expiresDate = Date(millis: timeStamp)
        } else {
            expiresDate = nil
        }
        
        let isActiveTrial = isTrial && isActive
        
        if isActiveTrial {
            self.status = .trial
        } else if isActive {
            self.status = .active
        } else {
            self.status = .inactive
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productID, forKey: .productID)
        try container.encode(environment, forKey: .environment)
        try container.encode(expiresDateTimestamp, forKey: .expiresDateTimestamp)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isTrial, forKey: .isTrial)
        try container.encode(transactionID, forKey: .transactionID)
    }

    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case productID = "product_id"
        case environment
        case expiresDateTimestamp = "expires_date_ms"
        case isTrial = "is_trial_period"
        case isActive = "is_active"
    }
    
    // MARK: - Status
    
    public enum Status {
        case inactive
        case trial
        case active
    }
}
