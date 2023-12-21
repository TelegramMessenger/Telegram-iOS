//
//  HTTPError.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

/**
 Custom error emit during handling of http response
 */
public enum HTTPError: Error {
    case runtimeError(String)
}
