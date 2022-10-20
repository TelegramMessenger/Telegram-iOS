//
//  CrowdinAPILog.swift
//  CrowdinSDK
//
//  Created by Nazar Yavornytskyy on 2/16/21.
//

import Foundation

public struct CrowdinAPILog {
    
    static func logRequest(
        method: String,
        url: String,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil,
        responseData: Data? = nil,
        error: Error? = nil
    ) {
        let message = [method, url].joined(separator: ", ")
        let attributedText = AttributedTextFormatter.make(
            method: method,
            url: url,
            parameters: parameters,
            headers: headers,
            body: body,
            responseData: responseData
        )
        
        guard url.contains("mapping") || url.contains("content") else {
            CrowdinLogsCollector.shared.add(log: .rest(with: message, attributedDetails: attributedText))
            return
        }
        
        CrowdinLogsCollector.shared.add(log: .info(with: message, attributedDetails: attributedText))
    }
    
    static func logRequest(
        type: CrowdinLogType = .info,
        stringURL: String,
        message: String
    ) {
        let attributedText: NSMutableAttributedString = NSMutableAttributedString()
        attributedText.append(AttributeFactory.make(.url(stringURL)))
        let log = CrowdinLog(type: type, message: message, attributedDetails: attributedText)
        CrowdinLogsCollector.shared.add(log: log)
    }
}
