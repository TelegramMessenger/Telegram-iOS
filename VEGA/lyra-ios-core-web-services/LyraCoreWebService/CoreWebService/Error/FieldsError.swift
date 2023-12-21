//
//  FieldsError.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public struct FieldsError: Decodable {
    public let gemAmount: Double?
    public let neededAmount: Double?
    public let balance: Double?
    public let adCreditBalance: Double?
}
