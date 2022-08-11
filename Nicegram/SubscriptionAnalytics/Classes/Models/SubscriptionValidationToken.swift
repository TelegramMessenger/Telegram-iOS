//
//  SubscriptionValidationToken.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/15/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

// MARK: - SubscriptionValidationToken

struct SubscriptionValidationToken: Codable, Equatable {
    
    // MARK: - Properties
    
    let vendorID: String
    let advertiseID: String
}
