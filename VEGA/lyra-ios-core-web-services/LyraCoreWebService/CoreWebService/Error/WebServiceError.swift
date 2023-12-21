//
//  WebServiceError.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public protocol WebServiceError {

    var data: Data? {get set}
    var error: Error? {get set}

    init(data: Data?, error: Error?, statusCode: Int?)
}
