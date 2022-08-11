//
//  MobyAnalyticsDevice.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/9/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import UIKit
import AdSupport

// MARK: - MobyAnalyticsDevice

final class MobyAnalyticsDevice {
        
    // MARK: - Properties
    
    private var _vendorID: String?
    private var _advertisingIdentifier: String?
    
    // MARK: - Shared
    
    private static let current = MobyAnalyticsDevice()
        
    static var vendorID: String? {
        return current._vendorID
    }
    
    static var advertisingIdentifier: String? {
        return current._advertisingIdentifier
    }
    
    static var bundleID: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "undefined"
        return bundleID
    }
    
    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "undefined"
        return version
    }
        
    // MARK: - Object life cycle
    
    private init() {}
    
    // MARK: - Methods
    
    static func setup(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        var vendorID: String?
        var advertisingIdentifier: String?
        
        group.enter()
        current.loadVendorID(maxAttemtpsCount: 5) { identifier in
            vendorID = identifier
            group.leave()
        }
        group.enter()
        current.loadAdvertisingIdentifier(maxAttemptsCount: 5) { identifier in
            advertisingIdentifier = identifier
            group.leave()
        }
        group.notify(queue: .main) {
            current._vendorID = vendorID
            current._advertisingIdentifier = advertisingIdentifier
            completion()
        }
    }
    
    private func loadVendorID(maxAttemtpsCount: Int, completion: @escaping (String?) -> Void) {
        let identifier = UIDevice.current.identifierForVendor?.uuidString
        
        if identifier == nil && maxAttemtpsCount > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let sSelf = self else { return }
                sSelf.loadVendorID(maxAttemtpsCount: maxAttemtpsCount - 1, completion: completion)
            }
        } else {
            completion(identifier)
        }
    }
    
    private func loadAdvertisingIdentifier(maxAttemptsCount: Int, completion: @escaping (String?) -> Void) {
        var isTrackingEnabled: Bool
        if #available(iOS 14.5, *) {
            // 'isAdvertisingTrackingEnabled' is deprecated from iOS 14.5 and always returns 'false'. If 'advertisingIdentifier' equal to "00000000-0000-0000-0000-000000000000" advertising tracking is unresolved.
            isTrackingEnabled = ASIdentifierManager.shared().advertisingIdentifier.uuidString != "00000000-0000-0000-0000-000000000000"
        } else {
            isTrackingEnabled = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        }
        let identifier = isTrackingEnabled ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : nil
        
        if !isTrackingEnabled {
            completion(identifier)
            return
        }
        
        if identifier == nil && maxAttemptsCount > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self]  in
                guard let sSelf = self else { return }
                sSelf.loadAdvertisingIdentifier(maxAttemptsCount: maxAttemptsCount - 1, completion: completion)
            }
        } else {
            completion(identifier)
        }
    }
}
