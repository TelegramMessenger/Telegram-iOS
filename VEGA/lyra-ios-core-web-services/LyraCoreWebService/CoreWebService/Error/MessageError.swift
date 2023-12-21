//
//  MessageError.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public struct MessageError: Decodable {
    public let code: Int?
    public let type: String?
    public let message: String?
    public let fields: FieldsError?
    public var daysDeleted: Int?
}
