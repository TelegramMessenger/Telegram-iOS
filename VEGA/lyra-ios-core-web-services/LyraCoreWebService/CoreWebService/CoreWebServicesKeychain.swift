//
//  CoreWebServicesKeychain.swift
//  CoreWebService
//
//  Created by Alvin Marana on 5/2/23.
//

import UIKit
import SimpleKeychain

class CoreWebServicesKeychain {
    
    private let AWS_IDENTITY_POOL_ID = "AWS_IDENTITY_POOL_ID"
    private let AWS_IDENTITY_ID = "AWS_IDENTITY_ID"
    private let AWS_IDENTITY_TOKEN = "AWS_IDENTITY_TOKEN"

    private let keychain = SimpleKeychain()

    private func getString(forKey key: String) -> String? {
        return try? keychain.string(forKey: key)
    }
    
    private func setString(_ string: String, forKey key: String) -> Bool {
        do {
            try keychain.set(string, forKey: key)
            return true
        } catch {
            return false
        }
    }
    
    private func deleteEntry(forKey key: String) -> Bool {
        do {
            try keychain.deleteItem(forKey: key)
            return true
        } catch {
            return false
        }
    }
    
    func clearAwsCredentials() {
        awsIdentityPoolId = nil
        awsIdentityId = nil
        awsIdentityToken = nil
    }
    
}

extension CoreWebServicesKeychain {
    
    var awsIdentityPoolId: String? {
        get {
            return getString(forKey: AWS_IDENTITY_POOL_ID)
        }
        set(value) {
            guard let value = value else {
                _ = deleteEntry(forKey: AWS_IDENTITY_POOL_ID)
                return
            }
            _ = setString(value, forKey: AWS_IDENTITY_POOL_ID)
        }
    }
    
    var awsIdentityId: String? {
        get {
            return getString(forKey: AWS_IDENTITY_ID)
        }
        set(value) {
            guard let value = value else {
                _ = deleteEntry(forKey: AWS_IDENTITY_ID)
                return
            }
            _ = setString(value, forKey: AWS_IDENTITY_ID)
        }
    }

    var awsIdentityToken: String? {
        get {
            return getString(forKey: AWS_IDENTITY_TOKEN)
        }
        set(value) {
            guard let value = value else {
                _ = deleteEntry(forKey: AWS_IDENTITY_TOKEN)
                return
            }
            _ = setString(value, forKey: AWS_IDENTITY_TOKEN)
        }
    }
    
}
