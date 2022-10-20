//
//  AnalyticsDeviceInformation.swift
//  TestSubsrcitpionAPI
//
//  Created by Vadim Suhodolskiy on 6/17/20.
//  Copyright © 2020 SD. All rights reserved.
//

import Foundation

public struct AnalyticsAccountDevice: Codable {
    let id: Int
    let accountID: Int
    let deviceID: Int
    let isActive: Bool
    private let dateLinkString: String?
    private let dateUnlinkString: String?
    
    var dateLink: Date? {
        if let dateLinkString = dateLinkString {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return dateFormatter.date(from: dateLinkString)
        }
        return nil
    }
    
    var dateUnlink: Date? {
        if let dateUnlinkString = dateUnlinkString {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return dateFormatter.date(from: dateUnlinkString)
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey  {
        case id = "id"
        case accountID = "account_id"
        case deviceID = "device_id"
        case isActive = "active"
        case dateLinkString = "date_link"
        case dateUnlinkString = "date_unlink"
    }
}

 
