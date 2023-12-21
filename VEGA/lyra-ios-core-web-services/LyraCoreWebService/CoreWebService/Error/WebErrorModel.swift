//
//  WebErrorModel.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public struct WebErrorModel: Decodable {
    public var meta: ErrorMeta?
    public var error: MessageError?
    
    public var message: String?
    public var statusCode: String?
    public var status: Bool?
    public var type: String?
    public var fields: FieldsError?

    var StatusCode: String?
    var Message: String?
    var Status: Bool?

    public init(message: String? = nil, statusCode: String? = nil, status: Bool? = nil, type: String? = nil, fields: FieldsError? = nil) {
        self.message = message
        self.statusCode = statusCode
        self.status = status
        self.type = type
        self.fields = fields
    }
}

