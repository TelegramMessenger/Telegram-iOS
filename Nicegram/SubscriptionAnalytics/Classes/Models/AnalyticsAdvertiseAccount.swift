//
//  AnalyticsAdsAccountInformation.swift
//  TestSubsrcitpionAPI
//
//  Created by Vadim Suhodolskiy on 6/18/20.
//  Copyright © 2020 SD. All rights reserved.
//

import Foundation

public struct AnalyticsAdvertiseAccount: Codable {
    public let id: Int
    public let accountID: Int
    public let accountDeviceID: Int
    public let storePackageID: Int
    public let iosIfa: String?
    public let iosIfv: String?
    public var googleAid: String?
    public var windowsAid: String?
    public var appsflyerID: String?
    public var adjustID: String?
    
    public init(id: Int,
                accountID: Int,
                accountDeviceID: Int,
                storePackageID: Int,
                iosIfa: String?,
                iosIfv: String?,
                googleAid: String?,
                windowsAid: String?,
                appsflyerId: String?,
                adjustId: String?) {
        self.id = id
        self.accountID = accountID
        self.accountDeviceID = accountDeviceID
        self.storePackageID = storePackageID
        self.iosIfa = iosIfa
        self.iosIfv = iosIfv
        self.googleAid = googleAid
        self.windowsAid = windowsAid
        self.appsflyerID = appsflyerId
        self.adjustID = adjustId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case accountID = "account_id"
        case accountDeviceID = "account_device_id"
        case storePackageID = "store_package_id"
        case iosIfa = "ios_ifa"
        case iosIfv = "ios_ifv"
        case googleAid = "google_aid"
        case windowsAid = "windows_aid"
        case appsflyerID = "appsflyer_id"
        case adjustID = "adjust_id"
    }
}
