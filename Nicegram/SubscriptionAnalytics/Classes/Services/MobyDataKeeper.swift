//
//  MobyDataKeeper.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/13/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

final class DataKeeper {
    private enum Keys: String {
        case renewableProducts = "moby_renewable_products_data"
        case subscriptionExpiryDate = "moby_subscription_expiry_date"
        case isMigrationPerformed = "moby_is_migration_performed"
        case accountID = "moby_account_id"
        case subscriptionValidationToken = "moby_subscription_validation_token"
    }
    
    private init() {}
    
    static var _storage = UserDefaults.standard
    
    static var accountID: Int? {
        get {
            return _storage.value(forKey: Keys.accountID.rawValue) as? Int
        } set {
            _storage.set(newValue, forKey: Keys.accountID.rawValue)
        }
    }
    
    static var cachedRenewableProducts: [RenewableProductDetails] {
        get {
            if let data = _storage.value(forKey: Keys.renewableProducts.rawValue) as? Data,
                let products = try? JSONDecoder().decode([RenewableProductDetails].self, from: data) {
                return products
            }
            return []
        } set {
            if let productsData = try? JSONEncoder().encode(newValue) {
                _storage.set(productsData, forKey: Keys.renewableProducts.rawValue)
            }
        }
    }
    
    static var recieptToken: SubscriptionValidationToken? {
        get {
            if let data = _storage.data(forKey: Keys.subscriptionValidationToken.rawValue),
                let token = try? JSONDecoder().decode(SubscriptionValidationToken.self, from: data) {
                return token
            }
            return nil
        } set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                _storage.setValue(data, forKeyPath: Keys.subscriptionValidationToken.rawValue)
            } else {
                _storage.setValue(nil, forKeyPath: Keys.subscriptionValidationToken.rawValue)
            }
        }
    }
    
    static var isMigrationPerformed: Bool {
        get {
            return _storage.bool(forKey: Keys.isMigrationPerformed.rawValue)
        } set {
            _storage.set(newValue, forKey: Keys.isMigrationPerformed.rawValue)
        }
    }
    
    static var subscriptionExpiryDate: Date? {
        get {
            return _storage.value(forKey: Keys.subscriptionExpiryDate.rawValue) as? Date
        } set {
            _storage.set(newValue, forKey: Keys.subscriptionExpiryDate.rawValue)
        }
    }
}
