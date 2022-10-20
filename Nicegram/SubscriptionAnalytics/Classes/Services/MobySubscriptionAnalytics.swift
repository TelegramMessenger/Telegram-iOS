//
//  MobyAnalytics.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/9/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation
import iAd

// MARK: - MobyAnalytics

final public class MobySubscriptionAnalytics {
    
    // MARK: - Constants
    
    private enum Constants {
        enum Endpoints {
            static let endPointURL = URL(string: "https://api.mbrx.app/v1")!
        }
    }
    
    // MARK: - Properties
    
    private var _apiKey: String?
        
    private var _isInizialized: Bool {
        return _apiKey != nil && _apiKey?.isEmpty == false
    }
        
    // MARK: - Shared
    
    private static let shared = MobySubscriptionAnalytics()
    
    public static var logger: MobyAnalyticsLoggerProtocol?
    
    public static var accountID: Int? {
        return DataKeeper.accountID
    }
    
    public static var haveValidSubscription: Bool {
        return SuscriptionStatusProvider.hasActiveSubscription
    }
    
    // MARK: - Methods
    
    public static func setup(
        apiKey: String,
        migrationSubscriptionExpiryDate: Date? = nil,
        updateAdvertiseAccountBlock: @escaping (inout AnalyticsAdvertiseAccount) -> Void,
        completion: @escaping (AnalyticsAdvertiseAccount?, ProductsInfoResult?) -> Void) {
        
        shared._apiKey = apiKey
        
        //in case when we haven't yer verified reciept
        if !DataKeeper.isMigrationPerformed {
            DataKeeper.subscriptionExpiryDate = migrationSubscriptionExpiryDate
        }
        
        // load vendor and advertise id
        MobyAnalyticsDevice.setup {
            // load advertise account
            loadAdvertiseAccount { account in
                if let account = account {
                    // update advertise account
                    
                    var updatedAccout = AnalyticsAdvertiseAccount(
                        id: account.id,
                        accountID: account.accountID,
                        accountDeviceID: account.accountDeviceID,
                        storePackageID: account.storePackageID,
                        iosIfa: MobyAnalyticsDevice.advertisingIdentifier ?? "",
                        iosIfv: MobyAnalyticsDevice.vendorID ?? "",
                        googleAid: nil,
                        windowsAid: nil,
                        appsflyerId: account.appsflyerID,
                        adjustId: account.adjustID
                    )
                    
                    updateAdvertiseAccountBlock(&updatedAccout)
                    
                    updateAdvirtiseAccount(updatedAccout) { _ in
                        logger?.logAdvertiseAccountLoaded(updatedAccout)
                        DataKeeper.accountID = account.id
                        // validate reciept
                        shared._initialRecieptSetup { result in
                            switch result {
                            case let .success(productsInfo):
                                completion(account,productsInfo)
                           
                            case .failure:
                                completion(account,nil)
                            }
                        }
                    }
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    @available(iOS 9.0, *)
    private func _requestAttributionData(completion: ((Bool) -> Void)? = nil) {
        ADClient.shared().requestAttributionDetails { [weak self] (attributeDetails, error) in
            guard let sSelf = self else { return }
            
            if error == nil, let details = attributeDetails {
                MobySubscriptionAnalytics.logger?.logAttributionDetails(details)
                if let jsonData = try? JSONSerialization.data(withJSONObject: details, options: .prettyPrinted) {
                    sSelf._updateAttribution(data: jsonData, repeateCount: 5, repeateTimeInterval: 5) { success in
                        completion?(success)
                    }
                } else {
                    completion?(false)
                }
            } else {
                completion?(false)
            }
        }
    }
    
    
    private func _updateAttribution(data: Data,
                                    repeateCount: Int,
                                    repeateTimeInterval: TimeInterval,
                                    completion: @escaping (Bool) -> Void) {
        _updateAttribution(data) { success in
            if success {
                completion(true)
            } else {
                if repeateCount <= 0 {
                    completion(false)
                } else {
                    DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + repeateTimeInterval) { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf._updateAttribution(data: data, repeateCount: repeateCount, repeateTimeInterval: repeateTimeInterval, completion: completion)
                    }
                }
            }
        }
    }
    
    private func _updateAttribution(_ data: Data, completion: @escaping (Bool) -> Void) {
        _debugInitializationPrecondition()
        
        guard _isInizialized else { return }
        
        var request = _createInitialRequest(path: "/advertise/ios",
                                            deviceID: MobyAnalyticsDevice.vendorID ?? "",
                                            apiKey: _apiKey!,
                                            httpMethod: .PUT)
        request.httpBody = data
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
               completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    public static func validateReciept(completion: ((Swift.Result<ProductsInfoResult,MobyValidationError>) -> Void)? = nil) {
        shared._validateReciept { result in
             DispatchQueue.main.async {
                 switch result {
                 case let .success(productsInfoResult):
                    completion?(.success(productsInfoResult))
            
                 case let .failure(error):
                     completion?(.failure(error))
                 }
             }
         }
    }
    
    private func _initialRecieptSetup(completion: @escaping (Swift.Result<ProductsInfoResult,Error>) -> Void)  {
        // Make sure that vendor id is updated
        updateVendorIfNeeded { [weak self] in
            guard let sSelf = self else { return }
            // Get current token
            let token = SubscriptionValidationToken(vendorID: MobyAnalyticsDevice.vendorID ?? "", advertiseID: MobyAnalyticsDevice.advertisingIdentifier ?? "")
            // Check if reciept was uploaded and tokens are same
            if let oldToken = DataKeeper.recieptToken, oldToken == token {
                // so we can check user without reciept uploading
                sSelf._checkUser(repeatTillSuccess: true, repeatTimeInterval: 5) { result in
                    switch result {
                    case let .success(products):
                        completion(.success(products))
                        
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            } else {
                // Oherwise perform reciept validation
                sSelf._validateReciept(repeateCount: 5, repeateTimeInterval: 2.5) { result in
                    switch result {
                    case let .success(result):
                        completion(.success(result))
                        
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func _checkUser(repeatTillSuccess: Bool,
                            repeatTimeInterval: TimeInterval,
                            completion: @escaping (Swift.Result<ProductsInfoResult, MobyAnalyticsServiceError>) -> Void) {
        _debugInitializationPrecondition()
        
        guard _isInizialized else { return }
        
        let request = _createInitialRequest(path: "/purchase/ios/transaction",
                                            deviceID: MobyAnalyticsDevice.vendorID ?? "",
                                            query: ["as_array":"true"],
                                            apiKey: _apiKey!,
                                            httpMethod: .GET)
        
        _apiCall(request: request, repeatTillSuccess: repeatTillSuccess, repeatTimeInterval: repeatTimeInterval) { (result: Swift.Result<ProductsInfoResult,MobyAnalyticsServiceError>) in
            DispatchQueue.main.async {
                switch result {
                case let .success(result):
                    DataKeeper.cachedRenewableProducts = result.transactions
                    completion(.success(result))
               
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func _validateReciept(repeateCount: Int,
                                  repeateTimeInterval: TimeInterval,
                                  completion: @escaping (Swift.Result<ProductsInfoResult, MobyValidationError>) -> Void) {
        _validateReciept { result in
            switch result {
            case let .success(result):
                completion(.success(result))
                
            case let .failure(error):
                if repeateCount <= 0 {
                    completion(.failure(error))
                } else {
                    DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + repeateTimeInterval) { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf._validateReciept(repeateCount: repeateCount, repeateTimeInterval: repeateTimeInterval, completion: completion)
                    }
                }
            }
        }
    }
        
    private func _validateReciept(completion: @escaping (Swift.Result<ProductsInfoResult, MobyValidationError>) -> Void) {
        _debugInitializationPrecondition()
        
        guard _isInizialized else { return }
        
        guard let recieptURL = Bundle.main.appStoreReceiptURL,
            let recieptData = try? Data(contentsOf: recieptURL) else {
                completion(.failure(.noRecieptData))
                return
        }
        
        let token = SubscriptionValidationToken(vendorID: MobyAnalyticsDevice.vendorID ?? "", advertiseID: MobyAnalyticsDevice.advertisingIdentifier ?? "")
        
        var request = _createInitialRequest(path: "purchase/ios/transaction",
                                            deviceID: MobyAnalyticsDevice.vendorID ?? "",
                                            query: ["as_array":"true"],
                                            apiKey: _apiKey!,
                                            httpMethod: .POST)
        request.httpBody = ["receipt": recieptData.base64EncodedString()].toJSON()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
          if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let data = data, let result = try? JSONDecoder().decode(ProductsInfoResult.self, from: data) {
                    DataKeeper.cachedRenewableProducts = result.transactions
                    DataKeeper.recieptToken = token
                    DataKeeper.isMigrationPerformed = true
                    completion(.success(result))
                } else {
                    completion(.failure(.invalidResponseData))
                }
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    let code = httpResponse.statusCode
                    switch code {
                    case 406:
                        completion(.failure(.invalidRequestBody))
                        
                    case 498:
                        completion(.failure(.invalidAPIKey))
                        
                    default:
                        completion(.failure(.unknown))
                    }
                } else {
                    completion(.failure(.unknown))
                }
            }
        }.resume()
    }
    
    public static func trackInstall(installInfo: InstallInfo? = nil, completion: ((StorePackageInstallInfo?) -> Void)? = nil) {
        shared._trackInstall(repeatTillSuccess: true, repeatTimeInterval: 5, installInfo: installInfo) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(info):
                    completion?(info)
                    
                case let .failure(error):
                    logger?.logError(apiPath: "/store/package-install", error: error)
                    completion?(nil)
                }
            }
        }
    }
    
    private func _trackInstall(
        repeatTillSuccess: Bool,
        repeatTimeInterval: TimeInterval,
        installInfo: InstallInfo?,
        completion: ((Swift.Result<StorePackageInstallInfo, MobyAnalyticsServiceError>) -> Void)? = nil) {
        _debugInitializationPrecondition()
                
        updateVendorIfNeeded { [weak self] in
            guard let sSelf = self, sSelf._isInizialized else { return }
            
            // update attribution
            if #available(iOS 9.0, *) {
                sSelf._requestAttributionData()
            }
                        
            var request = sSelf._createInitialRequest(
                path: "/store/package-install",
                deviceID: MobyAnalyticsDevice.vendorID ?? "",
                apiKey: sSelf._apiKey!,
                httpMethod: .POST
            )
            request.httpBody = installInfo?.toJSON()
            
            sSelf._apiCall(
                request: request,
                repeatTillSuccess: repeatTillSuccess,
                repeatTimeInterval: repeatTimeInterval,
                completionHandler: { (result: Swift.Result<StorePackageInstallInfo, MobyAnalyticsServiceError>) in
                    completion?(result)
            })
        }
    }
    
    /// Force refresh  advertising account.
    /// Use it when advertising id was updated.
    public static func refreshAdvertisingAccount(completion: ((Bool) -> Void)? = nil) {
        // Update vendor and idfa
        MobyAnalyticsDevice.setup {
            // load account from server
            loadAdvertiseAccount { account in
                guard let account = account else {
                    completion?(false)
                    return
                }
                
                let updatedAccout = AnalyticsAdvertiseAccount(
                    id: account.id,
                    accountID: account.accountID,
                    accountDeviceID: account.accountDeviceID,
                    storePackageID: account.storePackageID,
                    iosIfa: MobyAnalyticsDevice.advertisingIdentifier ?? "",
                    iosIfv: MobyAnalyticsDevice.vendorID ?? "",
                    googleAid: nil,
                    windowsAid: nil,
                    appsflyerId: account.appsflyerID,
                    adjustId: account.adjustID
                )

                // Log attribution event
                if #available(iOS 9.0, *) {
                    ADClient.shared().requestAttributionDetails { (attributeDetails, error) in
                        if error == nil, let details = attributeDetails {
                            MobySubscriptionAnalytics.logger?.logAttributionDetails(details)
                        }
                    }
                }

                updateAdvirtiseAccount(updatedAccout) { status in
                    completion?(status)
                }
            }
        }
    }
        
    public static func loadAdvertiseAccount(completion: @escaping (AnalyticsAdvertiseAccount?) -> Void) {
        shared._loadAdvertiseAccount(repeatTillSuccess: true, repeatTimeInterval: 5) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(account):
                    completion(account)
                    
                case let .failure(error):
                    completion(nil)
                    logger?.logError(apiPath: "/advertise/account", error: error)
                }
            }
        }
    }
        
    private func _loadAdvertiseAccount(
        repeatTillSuccess: Bool,
        repeatTimeInterval: TimeInterval,
        completion: @escaping (Swift.Result<AnalyticsAdvertiseAccount, MobyAnalyticsServiceError>) -> Void) {
        _debugInitializationPrecondition()
        
        guard _isInizialized else { return }
        
        let request = _createInitialRequest(
            path: "/advertise/account",
            deviceID: MobyAnalyticsDevice.vendorID ?? "",
            apiKey: _apiKey!,
            httpMethod: .GET
        )
        
        _apiCall(
            request: request,
            repeatTillSuccess: repeatTillSuccess,
            repeatTimeInterval: repeatTimeInterval,
            completionHandler: completion
        )
    }
    
    public static func updateAdvirtiseAccount(_ account: AnalyticsAdvertiseAccount, completion: @escaping (Bool) -> ()) {
        shared._updateAdvirtiseAccount(account, repeatTillSuccess: true, repeatTimeInterval: 5) { result in
            DispatchQueue.main.async {
                switch result{
                case .success:
                    completion(true)
                    
                case let .failure(error):
                    logger?.logError(apiPath: "/advertise/account", error: error)
                    completion(false)
                }
            }
        }
    }
    
    private func _updateAdvirtiseAccount(_ account: AnalyticsAdvertiseAccount,
                                         repeatTillSuccess: Bool,
                                         repeatTimeInterval: TimeInterval,
                                         completion: @escaping (Swift.Result<AnalyticsAdvertiseAccount, MobyAnalyticsServiceError>) -> Void) {
        _debugInitializationPrecondition()
        
        guard _isInizialized else { return }
        
        guard let data = try? JSONEncoder().encode(account) else { return }
        
        var request = _createInitialRequest(
            path: "/advertise/account",
            deviceID: MobyAnalyticsDevice.vendorID ?? "",
            apiKey: _apiKey!,
            httpMethod: .PUT
        )
        request.httpBody = data
        
        _apiCall(
            request: request,
            repeatTillSuccess: repeatTillSuccess,
            repeatTimeInterval: repeatTimeInterval,
            completionHandler: completion
        )
    }
    
    // MARK: - HTTP Methods
    
    private enum HTTPMethod: String {
        case GET
        case POST
        case PUT
    }
    
    // MARK: - Moby Analytics Service Error
     
     public enum MobyAnalyticsServiceError: Error {
         case recieptNotFound
         case invalidRequestBody
         case invalidAPIKey
         case noInternetConnection
         case unknown
     }
    
    // MARK: - Helpers
    
    private func updateVendorIfNeeded(competion: @escaping () -> Void) {
        if MobyAnalyticsDevice.vendorID == nil {
            MobyAnalyticsDevice.setup(completion: competion)
        } else {
            competion()
        }
    }
    
    private func _debugInitializationPrecondition() {
        #if DEBUG
        if !Self.shared._isInizialized {
            assert(false, "\(type(of: self)) must be initialized. Call initialize(deviceID:, apiKey:) on launch")
        }
        #endif
    }
    
    private func _createInitialRequest(path: String, deviceID: String, query: [String: String?] = [:], apiKey: String, httpMethod: HTTPMethod) -> URLRequest {
        let bundleID = Bundle.main.bundleIdentifier ?? "undefined"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "undefined"
        let headers = [
            "X-App-Device-Id": deviceID,
            "X-App-Package-Name": bundleID,
            "X-App-Package-Version": version,
            "X-App-Api-Key": apiKey,
            "Connection": "keep-alive",
            "Accept": "application/json",
            "Accept-Encoding": "gzip",
            "Accept-Charset": "utf-8",
            "Content-Type": "application/json"
        ]
        
        let url = Constants.Endpoints.endPointURL.appendingPathComponent(path).addQuery(query)!
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
    
    private func _apiCall<T: Codable>(
        request: URLRequest,
        repeatTillSuccess: Bool,
        repeatTimeInterval: TimeInterval,
        completionHandler: @escaping (Swift.Result<T,MobyAnalyticsServiceError>) -> Void) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let sSelf = self else { return }
                                    
            // check if not internet connection and try to repeat request if needed
            if let urlSessionError = error as NSError?,
                urlSessionError.code == NSURLErrorNotConnectedToInternet {
                if !repeatTillSuccess {
                    completionHandler(.failure(.noInternetConnection))
                } else {
                    DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + repeatTimeInterval) {
                        sSelf._apiCall(
                            request: request,
                            repeatTillSuccess: repeatTillSuccess,
                            repeatTimeInterval: repeatTimeInterval,
                            completionHandler: completionHandler
                        )
                    }
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                switch httpResponse.statusCode {
                case 406:
                    completionHandler(.failure(.invalidRequestBody))
                    return
                    
                case 498:
                    completionHandler(.failure(.invalidAPIKey))
                    return
                    
                default: break
                }
            }
            
            let jsonDecoder = JSONDecoder()
            
            do {
                let model = try jsonDecoder.decode(T.self, from: data ?? Data())
                completionHandler(.success(model))
            } catch {
                completionHandler(.failure(.unknown))
            }
        }.resume()
    }
}

fileprivate extension Dictionary {
    func toJSON() -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
        } catch {
            return nil
        }
    }
}
