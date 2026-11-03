//
//  SetLogVerbosityLevel.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Sets the verbosity level of the internal logging of TDLib. Can be called synchronously
public struct SetLogVerbosityLevel: Codable, Equatable, Hashable {

    /// New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings, value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
    public let newVerbosityLevel: Int?


    public init(newVerbosityLevel: Int?) {
        self.newVerbosityLevel = newVerbosityLevel
    }
}

