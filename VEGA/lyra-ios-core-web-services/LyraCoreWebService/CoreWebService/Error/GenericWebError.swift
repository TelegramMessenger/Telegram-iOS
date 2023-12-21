//
//  GenericWebError.swift
//  CoreWebService
//
//  Created by Alvin Marana on 3/16/23.
//

import UIKit

public class GenericWebError: WebServiceError, Error {
    
    public var data: Data?
    public var error: Error?
    public var errorModel: WebErrorModel?
    private var receivedStatusCode: Int?
    fileprivate var cause: String?

    public required init(data: Data?, error: Error?, statusCode: Int? = nil) {
        self.data = data
        self.error = error
        self.parseError()
        self.receivedStatusCode = statusCode
    }

    public func parseError() {
        
        guard let data = self.data else {
            self.setAsGenericError()
            return
        }
        
        
        do {
            let errorModel = try JSONDecoder().decode(WebErrorModel.self, from: data)
            self.errorModel = errorModel
        } catch {
            print("xxx ", error)
            self.setAsGenericError()
        }
        
        
          
    }
    
    public var statusCode: Int? {
        
        if let meta = errorModel?.meta {
            return meta.statusCode
        }
        
        if let error = errorModel?.error,
           let code = error.code {
            return Int(code)
        }
        
        if let statusCode = errorModel?.statusCode {
            return Int(statusCode)
        }
                
        if let statusCode = errorModel?.StatusCode {
            return Int(statusCode)
        }
        
        if let statusCode = self.receivedStatusCode {
            return statusCode
        }
        
        return nil
    }
    
    public var errorMessage: String? {
        
        if let message = errorModel?.message {
            return message
        }
        
        if let message = errorModel?.error?.message {
            return message
        }
        
        if let message = errorModel?.message {
            return message
        }
        
        if let message = errorModel?.Message {
            return message
        }
        
        if let cause = cause {
            return cause
        }
        
        return nil
    }
        
    public var errorType: CustomErrorType? {
        guard let type = errorModel?.type else {
            return nil
        }
        
        return CustomErrorType(rawValue: type)
    }
    
    public var fields: FieldsError? {
        return errorModel?.fields ?? errorModel?.error?.fields
    }
    
    private func setAsGenericError() {
        self.error = HTTPError.runtimeError(Self.ErrorMessage.default)
        self.errorModel = WebErrorModel(message: Self.ErrorMessage.default)
    }
    
}

extension GenericWebError {
    
    /// Create generic web error on runtime with message
    public static func errorWithCause(_ message: String) -> GenericWebError {
        let error = GenericWebError(data: nil, error: nil)
        error.cause = message
        return error
    }
    
    public struct ErrorMessage {
        public static let `default`: String = "Something went wrong. Please try again."
        public static func defaultMessage(statusCode: Int) -> String {
            
            switch statusCode {
            case 500...599:
                return "System is under maintenance. Please try again later."
                
            // TODO: Add default error message for other errors
                
            default:
                return Self.default
            }
        }
    }
}
