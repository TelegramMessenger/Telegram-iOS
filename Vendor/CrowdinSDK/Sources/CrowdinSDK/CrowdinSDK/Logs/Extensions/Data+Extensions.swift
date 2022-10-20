//
//  Data+Extensions.swift
//  CrowdinSDK
//
//  Created by Nazar Yavornytskyy on 2/18/21.
//

import Foundation

extension Data {
    
    var prettyJSONString: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return prettyPrintedString
    }
}
