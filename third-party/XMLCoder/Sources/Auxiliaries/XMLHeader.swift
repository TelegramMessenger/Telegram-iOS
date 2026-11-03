// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/18/18.
//

import Foundation

/// Type that allows overriding XML header during encoding. Pass a value of this type to the `encode`
/// function of `XMLEncoder` to specify the exact value of the header you'd like to see in the encoded
/// data.
public struct XMLHeader: Sendable {
    /// The XML standard that the produced document conforms to.
    public let version: Double?

    /// The encoding standard used to represent the characters in the produced document.
    public let encoding: String?

    /// Indicates whether a document relies on information from an external source.
    public let standalone: String?

    public init(version: Double? = nil, encoding: String? = nil, standalone: String? = nil) {
        self.version = version
        self.encoding = encoding
        self.standalone = standalone
    }

    func isEmpty() -> Bool {
        return version == nil && encoding == nil && standalone == nil
    }

    func toXML() -> String? {
        guard !isEmpty() else {
            return nil
        }

        var string = "<?xml"

        if let version = version {
            string += " version=\"\(version)\""
        }

        if let encoding = encoding {
            string += " encoding=\"\(encoding)\""
        }

        if let standalone = standalone {
            string += " standalone=\"\(standalone)\""
        }

        string += "?>\n"

        return string
    }
}
