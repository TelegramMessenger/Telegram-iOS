// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Benjamin Wetherfield on 7/17/19.
//

/// An empty marker protocol that can be used in place of `CodingKey`. It must be used when
/// attempting to encode and decode union-type–like enums with associated values to and from `XML`
/// choice elements.
///
/// - Important: In order for your `XML`-destined `Codable` type to be encoded and/or decoded
/// properly, you must conform your custom `CodingKey` type additionally to `XMLChoiceCodingKey`.
///
/// For example, say you have defined a type which can hold _either_ an `Int` _or_ a `String`:
///
///     enum IntOrString {
///         case int(Int)
///         case string(String)
///     }
///
/// Implementing the requirements for the `Codable` protocol like this:
///
///     extension IntOrString: Codable {
///         enum CodingKeys: String, XMLChoiceCodingKey {
///             case int
///             case string
///         }
///
///         func encode(to encoder: Encoder) throws {
///             var container = encoder.container(keyedBy: CodingKeys.self)
///             switch self {
///             case let .int(value):
///                 try container.encode(value, forKey: .int)
///             case let .string(value):
///                 try container.encode(value, forKey: .string)
///             }
///         }
///
///         init(from decoder: Decoder) throws {
///             let container = try decoder.container(keyedBy: CodingKeys.self)
///             do {
///                 self = .int(try container.decode(Int.self, forKey: .int))
///             } catch {
///                 self = .string(try container.decode(String.self, forKey: .string))
///             }
///         }
///     }
///
/// Retroactively conform the `CodingKeys` enum to `XMLChoiceCodingKey` when targeting `XML` as your
/// encoded format.
///
///     extension IntOrString.CodingKeys: XMLChoiceCodingKey {}
///
/// - Note: The `XMLChoiceCodingKey` marker protocol allows the `XMLEncoder` / `XMLDecoder` to
/// resolve ambiguities particular to the `XML` format between nested unkeyed container elements and
/// choice elements.
public protocol XMLChoiceCodingKey: CodingKey {}
