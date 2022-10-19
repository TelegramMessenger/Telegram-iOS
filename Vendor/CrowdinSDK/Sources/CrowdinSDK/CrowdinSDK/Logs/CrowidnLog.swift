//
//  CrowidnLog.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 11.08.2020.
//

import UIKit

enum CrowdinLogType: String {
    
    case info
    case error
    case warning
    case rest
}

extension CrowdinLogType {
    
    var color: UIColor {
        switch self {
        case .error:
            return .red
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .rest:
            return .orange
        }
    }
}

public struct CrowdinLog {
    let date = Date()
    let type: CrowdinLogType
    let message: String
    var attributedDetails: NSAttributedString? = nil
    
    static func info(with message: String, attributedDetails: NSAttributedString? = nil) -> CrowdinLog {
        var log = CrowdinLog(type: .info, message: message)
        log.attributedDetails = attributedDetails
        
        return log
    }
    
    static func error(with message: String, attributedDetails: NSAttributedString? = nil) -> CrowdinLog {
        var log = CrowdinLog(type: .error, message: message)
        log.attributedDetails = attributedDetails
        
        return log
    }
    
    static func warning(with message: String, attributedDetails: NSAttributedString? = nil) -> CrowdinLog {
        var log = CrowdinLog(type: .warning, message: message)
        log.attributedDetails = attributedDetails
        
        return log
    }
    
    static func rest(with message: String, attributedDetails: NSAttributedString? = nil) -> CrowdinLog {
        var log = CrowdinLog(type: .rest, message: message)
        log.attributedDetails = attributedDetails
        
        return log
    }
}
