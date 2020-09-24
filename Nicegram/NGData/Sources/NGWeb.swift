//
//  NGweb.swift
//  TelegramUI
//
//  Created by Sergey on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import NGEnv
import NGLogging

fileprivate let LOGTAG = extractNameFromPath(#file)

public func ngAPIsetDefaults() {
    let UD = UserDefaults(suiteName: "NGAPISETTINGS")
    UD?.register(defaults: ["SYNC_CHATS": false])
    UD?.register(defaults: ["RESTRICED": []])
    UD?.register(defaults: ["RESTRICTION_REASONS": []])
    UD?.register(defaults: ["ALLOWED": []])
    // UD?.register(defaults: ["PREMIUM": false])
}

public class NGAPISETTINGS {
    let UD = UserDefaults(suiteName: "NGAPISETTINGS")
    
    public init() {
        ngAPIsetDefaults()
    }
    
    public var SYNC_CHATS: Bool {
        get {
            return UD?.bool(forKey: "SYNC_CHATS") ?? false
        }
        set {
            UD?.set(newValue, forKey: "SYNC_CHATS")
        }
    }
    
    
    public var RESTRICTED: [Int64] {
        get {
            return UD?.array(forKey: "RESTRICTED") as? [Int64] ?? []
        }
        set {
            UD?.set(newValue, forKey: "RESTRICTED")
        }
    }
    
    public var RESTRICTION_REASONS: [String] {
        get {
            return UD?.array(forKey: "RESTRICTION_REASONS") as? [String] ?? []
        }
        set {
            UD?.set(newValue, forKey: "RESTRICTION_REASONS")
        }
    }
    
    public var ALLOWED: [Int64] {
        get {
            return UD?.array(forKey: "ALLOWED") as? [Int64] ?? []
        }
        set {
            UD?.set(newValue, forKey: "ALLOWED")
        }
    }
    
//    public var PREMIUM: Bool {
//        get {
//            return UD?.bool(forKey: "PREMIUM") ?? false
//        }
//        set {
//            UD?.set(newValue, forKey: "PREMIUM")
//        }
//    }
    
}
public var VARNGAPISETTINGS = NGAPISETTINGS()


extension String {
    func convertToDictionary() -> [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                ngLog("\(String(data: data, encoding: .utf8)) " + error.localizedDescription + " \(error)", LOGTAG)
            }
        }
        return nil
    }
}

public func requestApi(_ path: String, pathParams: [String] = [], completion: @escaping (_ apiResult: [String: Any]?) -> Void) {
    let startTime = CFAbsoluteTimeGetCurrent()
    ngLog("DECLARING REQUEST \(path)")
    var urlString = NGENV.ng_api_url + path + "/"
    for param in pathParams {
        urlString = urlString + String(param) + "/"
    }
    let url = URL(string: urlString)!
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        ngLog("PROCESSED REQUEST \(path) IN \(timeElapsed) s.", LOGTAG)
        if let error = error {
            ngLog("Error requesting settings: \(error)", LOGTAG)
        } else {
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    if let data = data, let dataString = String(data: data, encoding: .utf8) {
                        completion(dataString.convertToDictionary())
                    }
                }
            }
        }
    }
    task.resume()
}

public func getNGSettings(_ userId: Int64, completion: @escaping (_ sync: Bool, _ rreasons: [String], _ allowed: [Int64], _ restricted: [Int64], _ premiumStatus: Bool, _ betaPremiumStatus: Bool) -> Void) {
    requestApi("settings", pathParams: [String(userId)], completion: { (apiResponse) -> Void in
        var syncChats = VARNGAPISETTINGS.SYNC_CHATS
        var restricitionReasons = VARNGAPISETTINGS.RESTRICTION_REASONS
        var allowedChats = VARNGAPISETTINGS.ALLOWED
        var restrictedChats = VARNGAPISETTINGS.RESTRICTED
        var localPremium = NGSettings.premium
        // var betaPremium = SecureNiceSettings().isBetaPremium
        
        if let response = apiResponse {
            if let settings = response["settings"] {
                if  let syncSettings = (settings as! [String: Any])["sync_chats"] {
                    syncChats = syncSettings as! Bool
                }
            }
            
            if let reasons = response["reasons"] {
                restricitionReasons = reasons as! [String]
            }
            
            if let allowed = response["allowed"] {
                allowedChats = allowed as! [Int64]
            }
            
            if let restricted = response["restricted"] {
                restrictedChats = restricted as! [Int64]
            }
            
            if let premium = response["premium"] {
                localPremium = premium as! Bool
            }
            
            // if let remoteBetaPremium = response["beta_premium"] {
            //     betaPremium = remoteBetaPremium as! Bool
            // }
            
        }
        completion(syncChats, restricitionReasons, allowedChats, restrictedChats, localPremium, false)
    })
}

public func updateNGInfo(userId: Int64) {
    getNGSettings(userId, completion: { (sync, rreasons, allowed, restricted, isPremium, isBetaPremium) -> Void in
        VARNGAPISETTINGS.SYNC_CHATS = sync
        VARNGAPISETTINGS.RESTRICTED = restricted
        VARNGAPISETTINGS.ALLOWED = allowed
        VARNGAPISETTINGS.RESTRICTION_REASONS = rreasons
        
        // VarPremiumSettings.isPremium = isPremium
        // SecureNiceSettings().isBetaPremium = isBetaPremium
        
        ngLog("SYNC_CHATS \(VARNGAPISETTINGS.SYNC_CHATS)\nRESTRICTED \(VARNGAPISETTINGS.RESTRICTED)\nALLOWED \(VARNGAPISETTINGS.ALLOWED)\nRESTRICTED_REASONS count \(VARNGAPISETTINGS.RESTRICTION_REASONS.count)\nPREMIUM", LOGTAG)
    })
}


public func requestValidator(_ receipt: Data,  completion: @escaping (_ apiResult: String) -> Void) {
    let startTime = CFAbsoluteTimeGetCurrent()
    ngLog("DECLARING REQUEST VALIDATOR", LOGTAG)
    var urlString = NGENV.validator_url
    
    let url = URL(string: urlString)!
    var request : URLRequest = URLRequest(url: url)
    request.httpBody = receipt
    request.httpMethod = "POST"
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        ngLog("PROCESSED REQUEST VALIDATOR IN \(timeElapsed) s.", LOGTAG)
        if let error = error {
            ngLog("Error validating: \(error)", LOGTAG)
            completion("error")
        } else {
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    if let data = data, let dataString = String(data: data, encoding: .utf8) {
                        completion(dataString)
                    }
                }
            }
        }
    }
    task.resume()
}



public func validatePremium(_ current: Bool, forceValid: Bool = false) {
    let sem = DispatchSemaphore(value: 0)
    if (current) {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
            let data = try? Data(contentsOf: receiptURL) else {
                NGSettings.premium = false
                ngLog("Hello hacker?????", LOGTAG)
                sem.signal()
                return
        }

        let encodedData = data.base64EncodedData(options: [])
        requestValidator(encodedData, completion: { validStatus in
            if validStatus == "0" { // Hacker
                NGSettings.premium = false
                ngLog("Hello hacker", LOGTAG)
                // preconditionFailure("Hello hacker")
            } else if validStatus == "1" { // OK
                ngLog("Okie-dokie", LOGTAG)
            } else { // Error
                if forceValid {
                    NGSettings.premium = false
                    ngLog("Hello hacker?", LOGTAG)
                }
            }
            sem.signal()
            return
        })
    }
    sem.wait()
    return
}

