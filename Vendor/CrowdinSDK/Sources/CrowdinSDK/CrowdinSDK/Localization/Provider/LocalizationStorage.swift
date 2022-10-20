//
//  LocalizationStorage.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/3/19.
//

import Foundation

/// Closure with localization data. Contains list of all available languages, strings and plurals localizations.
public typealias LocalizationStorageCompletion = (_ localizations: [String]?, _ localization: String, _ strings: [String: String]?, _ plurals: [AnyHashable: Any]?) -> Void
public typealias LocalizationStorageError = (_ error: Error) -> Void

/// Protocol for storage with localization data.
@objc public protocol LocalizationStorageProtocol {
    /// List of all available localizations.
    var localizations: [String] { get }
    
    /// Current localization.
    var localization: String { get set }
    
    /// Method for clearing up all the data for localization storage.sb
    func deintegrate()
    
    /// Method for data fetching.
    ///
    /// - Parameter completion: Completion block called after localization data fetched.
    func fetchData(completion: @escaping LocalizationStorageCompletion, errorHandler: LocalizationStorageError?)
}
