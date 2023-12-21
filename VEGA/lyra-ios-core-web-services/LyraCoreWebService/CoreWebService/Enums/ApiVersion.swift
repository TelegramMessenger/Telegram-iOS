//
//  ApiVersion.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public enum ApiVersion {
    case notificationV1
    case v1
    case v2
    case v3
    case v4
    case noVersion

    var path: String {
        switch self {
        case .notificationV1:
            return "/v1"
        case .v1:
            return "/api/v1"
        case .v2:
            return "/api/v2"
        case .v3:
            return "/api/v3"
        case .v4:
            return "/api/v4"
        case .noVersion:
            return "/api"
        }
    }
}

