// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/25/17.
//

import Foundation

/// XMLReferencingEncoder is a special subclass of _XMLEncoder which has its
/// own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a
// superclass -- the lifetime of the encoder should not escape the scope it's
/// created in, but it doesn't necessarily know when it's done being used
/// (to write to the original container).
class XMLReferencingEncoder: XMLEncoderImplementation {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an unkeyed container.
        case unkeyed(SharedBox<UnkeyedBox>, Int)

        /// Referencing a specific key in a keyed container.
        case keyed(SharedBox<KeyedBox>, String)

        /// Referencing a specific key in a keyed container.
        case choice(SharedBox<ChoiceBox>, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    let encoder: XMLEncoderImplementation

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(
        referencing encoder: XMLEncoderImplementation,
        at index: Int,
        wrapping sharedUnkeyed: SharedBox<UnkeyedBox>
    ) {
        self.encoder = encoder
        reference = .unkeyed(sharedUnkeyed, index)
        super.init(
            options: encoder.options,
            nodeEncodings: encoder.nodeEncodings,
            codingPath: encoder.codingPath
        )

        codingPath.append(XMLKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(
        referencing encoder: XMLEncoderImplementation,
        key: CodingKey,
        convertedKey: CodingKey,
        wrapping sharedKeyed: SharedBox<KeyedBox>
    ) {
        self.encoder = encoder
        reference = .keyed(sharedKeyed, convertedKey.stringValue)
        super.init(
            options: encoder.options,
            nodeEncodings: encoder.nodeEncodings,
            codingPath: encoder.codingPath
        )

        codingPath.append(key)
    }

    init(
        referencing encoder: XMLEncoderImplementation,
        key: CodingKey,
        convertedKey: CodingKey,
        wrapping sharedKeyed: SharedBox<ChoiceBox>
    ) {
        self.encoder = encoder
        reference = .choice(sharedKeyed, convertedKey.stringValue)
        super.init(
            options: encoder.options,
            nodeEncodings: encoder.nodeEncodings,
            codingPath: encoder.codingPath
        )

        codingPath.append(key)
    }

    // MARK: - Coding Path Operations

    override var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return storage.count == codingPath.count - encoder.codingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let box: Box
        switch self.storage.count {
        case 0: box = KeyedBox()
        case 1: box = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case let .unkeyed(sharedUnkeyedBox, index):
            sharedUnkeyedBox.withShared { unkeyedBox in
                unkeyedBox.insert(box, at: index)
            }
        case let .keyed(sharedKeyedBox, key):
            sharedKeyedBox.withShared { keyedBox in
                keyedBox.elements.append(box, at: key)
            }
        case let .choice(sharedChoiceBox, key):
            sharedChoiceBox.withShared { choiceBox in
                choiceBox.element = box
                choiceBox.key = key
            }
        }
    }
}
