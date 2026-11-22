// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Joseph Mattiello on 1/24/19.
//

/** Allows conforming types to specify how its properties will be encoded.

 For example:
 ```swift
 struct Book: Codable, Equatable, DynamicNodeEncoding {
     let id: UInt
     let title: String
     let categories: [Category]

     enum CodingKeys: String, CodingKey {
         case id
         case title
         case categories = "category"
     }

     static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
         switch key {
         case Book.CodingKeys.id: return .both
         default: return .element
         }
     }
 }
 ```
 produces XML of this form for values of type `Book`:

 ```xml
 <book id="123">
     <id>123</id>
     <title>Cat in the Hat</title>
     <category>Kids</category>
     <category>Wildlife</category>
 </book>
 ```
 */
public protocol DynamicNodeEncoding: Encodable, Sendable {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding
}

extension Array: DynamicNodeEncoding where Element: DynamicNodeEncoding {
    public static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return Element.nodeEncoding(for: key)
    }
}

public extension DynamicNodeEncoding where Self: Collection, Self.Iterator.Element: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return Element.nodeEncoding(for: key)
    }
}
