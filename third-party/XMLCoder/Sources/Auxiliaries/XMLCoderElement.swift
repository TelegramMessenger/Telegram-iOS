// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/18/18.
//

import Foundation

struct XMLCoderElement: Equatable, Sendable {
    struct Attribute: Equatable, Sendable {
        let key: String
        let value: String
    }

    let key: String
    private(set) var stringValue: String?
    private(set) var elements: [XMLCoderElement] = []
    private(set) var attributes: [Attribute] = []
    private(set) var containsTextNodes: Bool = false

    var isStringNode: Bool {
        return key == ""
    }

    var isCDATANode: Bool {
        return key == "#CDATA"
    }

    var isTextNode: Bool {
        return isStringNode || isCDATANode
    }

    private var isInlined: Bool {
        return key.isEmpty
    }

    init(
        key: String,
        elements: [XMLCoderElement] = [],
        attributes: [Attribute] = []
    ) {
        self.key = key
        stringValue = nil
        self.elements = elements
        self.attributes = attributes
    }

    init(
        key: String,
        stringValue string: String,
        attributes: [Attribute] = []
    ) {
        self.key = key
        elements = [XMLCoderElement(stringValue: string)]
        self.attributes = attributes
        containsTextNodes = true
    }

    init(
        key: String,
        cdataValue string: String,
        attributes: [Attribute] = []
    ) {
        self.key = key
        elements = [XMLCoderElement(cdataValue: string)]
        self.attributes = attributes
        containsTextNodes = true
    }

    init(stringValue string: String) {
        key = ""
        stringValue = string
    }

    init(cdataValue string: String) {
        key = "#CDATA"
        stringValue = string
    }

    mutating func append(element: XMLCoderElement) {
        elements.append(element)
        containsTextNodes = containsTextNodes || element.isTextNode
    }

    mutating func append(string: String) {
        if elements.last?.isTextNode == true {
            let oldValue = elements[elements.count - 1].stringValue ?? ""
            elements[elements.count - 1].stringValue = oldValue + string
        } else {
            elements.append(XMLCoderElement(stringValue: string))
        }
        containsTextNodes = true
    }

    mutating func append(cdata string: String) {
        if elements.last?.isCDATANode == true {
            let oldValue = elements[elements.count - 1].stringValue ?? ""
            elements[elements.count - 1].stringValue = oldValue + string
        } else {
            elements.append(XMLCoderElement(cdataValue: string))
        }
        containsTextNodes = true
    }

    mutating func trimTextNodes() {
        guard containsTextNodes else { return }
        for idx in elements.indices {
            elements[idx].stringValue = elements[idx].stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func transformToBoxTree() -> Box {
        if isTextNode {
            return StringBox(stringValue!)
        }

        let attributes = KeyedStorage(self.attributes.map { attribute in
            (key: attribute.key, value: StringBox(attribute.value) as SimpleBox)
        })

        var storage = KeyedStorage<String, Box>()
        // storage.reserveCapacity(self.elements)

        for element in self.elements {

            let hasElements = !element.elements.isEmpty
            let hasAttributes = !element.attributes.isEmpty
            let hasText = element.stringValue != nil
            
            if hasElements || hasAttributes {
                storage.append(element.transformToBoxTree(), at: element.key)
            } else if hasText {
                storage.append(element.transformToBoxTree(), at: element.key)
            } else {
                storage.append(SingleKeyedBox(key: element.key, element: NullBox()), at: element.key)
            }
        }

        return KeyedBox(elements: storage, attributes: attributes)
    }

    func toXMLString(
        with header: XMLHeader?,
        doctype: XMLDocumentType?,
        escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        formatting: XMLEncoder.OutputFormatting,
        indentation: XMLEncoder.PrettyPrintIndentation
    ) -> String {
        var base = ""
        
        if let header = header, let headerXML = header.toXML() {
            base += headerXML
        }
        
        if let doctype = doctype {
            base += doctype.toXML()
        }
        
        return base + _toXMLString(escapedCharacters, formatting, indentation)
    }

    private func formatUnsortedXMLElements(
        _ string: inout String,
        _ level: Int,
        _ escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        _ formatting: XMLEncoder.OutputFormatting,
        _ indentation: XMLEncoder.PrettyPrintIndentation,
        _ prettyPrinted: Bool
    ) {
        formatXMLElements(
            from: elements,
            into: &string,
            at: level,
            escapedCharacters: escapedCharacters,
            formatting: formatting,
            indentation: indentation,
            prettyPrinted: prettyPrinted
        )
    }

    fileprivate func elementString(
        for element: XMLCoderElement,
        at level: Int,
        formatting: XMLEncoder.OutputFormatting,
        indentation: XMLEncoder.PrettyPrintIndentation,
        escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        prettyPrinted: Bool
    ) -> String {
        if let stringValue = element.stringValue {
            if element.isCDATANode {
                return "<![CDATA[\(stringValue)]]>"
            } else {
                return stringValue.escape(escapedCharacters.elements)
            }
        }

        var string = ""
        let indentLevel = isInlined ? level : level + 1
        string += element._toXMLString(indented: indentLevel, escapedCharacters, formatting, indentation)
        string += prettyPrinted && !isInlined ? "\n" : ""
        return string
    }

    fileprivate func formatSortedXMLElements(
        _ string: inout String,
        _ level: Int,
        _ escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        _ formatting: XMLEncoder.OutputFormatting,
        _ indentation: XMLEncoder.PrettyPrintIndentation,
        _ prettyPrinted: Bool
    ) {
        formatXMLElements(from: elements.sorted { $0.key < $1.key },
                          into: &string,
                          at: level,
                          escapedCharacters: escapedCharacters,
                          formatting: formatting,
                          indentation: indentation,
                          prettyPrinted: prettyPrinted)
    }

    fileprivate func formatXMLAttributes(
        from attributes: [Attribute],
        into string: inout String,
        charactersEscapedInAttributes: [(String, String)]
    ) {
        for attribute in attributes {
            string += " \(attribute.key)=\"\(attribute.value.escape(charactersEscapedInAttributes))\""
        }
    }

    fileprivate func formatXMLElements(
        from elements: [XMLCoderElement],
        into string: inout String,
        at level: Int,
        escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        formatting: XMLEncoder.OutputFormatting,
        indentation: XMLEncoder.PrettyPrintIndentation,
        prettyPrinted: Bool
    ) {
        for element in elements {
            string += elementString(for: element,
                                    at: level,
                                    formatting: formatting,
                                    indentation: indentation,
                                    escapedCharacters: escapedCharacters,
                                    prettyPrinted: prettyPrinted && !containsTextNodes)
        }
    }

    private func formatXMLAttributes(
        _ formatting: XMLEncoder.OutputFormatting,
        _ string: inout String,
        _ charactersEscapedInAttributes: [(String, String)]
    ) {
        let attributesBelongingToContainer = self.elements.filter {
            $0.key.isEmpty && !$0.attributes.isEmpty
        }.flatMap {
            $0.attributes
        }
        let allAttributes = self.attributes + attributesBelongingToContainer

        let attributes = formatting.contains(.sortedKeys) ?
            allAttributes.sorted(by: { $0.key < $1.key }) :
            allAttributes
        formatXMLAttributes(
            from: attributes,
            into: &string,
            charactersEscapedInAttributes: charactersEscapedInAttributes
        )
    }

    private func formatXMLElements(
        _ escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        _ formatting: XMLEncoder.OutputFormatting,
        _ indentation: XMLEncoder.PrettyPrintIndentation,
        _ string: inout String,
        _ level: Int,
        _ prettyPrinted: Bool
    ) {
        if formatting.contains(.sortedKeys) {
            formatSortedXMLElements(
                &string, level, escapedCharacters, formatting, indentation, prettyPrinted
            )
            return
        }
        formatUnsortedXMLElements(
            &string, level, escapedCharacters, formatting, indentation, prettyPrinted
        )
    }

    private func _toXMLString(
        indented level: Int = 0,
        _ escapedCharacters: (elements: [(String, String)], attributes: [(String, String)]),
        _ formatting: XMLEncoder.OutputFormatting,
        _ indentation: XMLEncoder.PrettyPrintIndentation
    ) -> String {
        let prettyPrinted = formatting.contains(.prettyPrinted)
        let prefix: String
        switch indentation {
        case let .spaces(count) where prettyPrinted && !isInlined:
            prefix = String(repeating: " ", count: level * count)
        case let .tabs(count) where prettyPrinted && !isInlined:
            prefix = String(repeating: "\t", count: level * count)
        default:
            prefix = ""
        }
        var string = prefix

        if !key.isEmpty {
            string += "<\(key)"
            formatXMLAttributes(formatting, &string, escapedCharacters.attributes)
        }

        if !elements.isEmpty || formatting.contains(.noEmptyElements) {
            let hasOnlyIntrinsicContent = elements.allSatisfy { element in
                element.key.isEmpty && !element.elements.contains { !$0.key.isEmpty }
            }
            let prettyPrintElements = prettyPrinted && !containsTextNodes && !hasOnlyIntrinsicContent
            if !key.isEmpty {
                string += prettyPrintElements ? ">\n" : ">"
            }
            if !elements.isEmpty {
                formatXMLElements(escapedCharacters, formatting, indentation, &string, level, prettyPrintElements)
            }

            if prettyPrintElements { string += prefix }
            if !key.isEmpty {
                string += "</\(key)>"
            }
        } else {
            if !key.isEmpty {
                string += " />"
            }
        }

        return string
    }
}

// MARK: - Convenience Initializers

extension XMLCoderElement {
    init(key: String, isStringBoxCDATA isCDATA: Bool, box: UnkeyedBox, attributes: [Attribute] = []) {
        if let containsChoice = box as? [ChoiceBox] {
            self.init(
                key: key,
                elements: containsChoice.map {
                    XMLCoderElement(key: $0.key, isStringBoxCDATA: isCDATA, box: $0.element)
                },
                attributes: attributes
            )
        } else {
            self.init(
                key: key,
                elements: box.map { XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: $0) },
                attributes: attributes
            )
        }
    }

    init(key: String, isStringBoxCDATA: Bool, box: ChoiceBox, attributes: [Attribute] = []) {
        self.init(
            key: key,
            elements: [
                XMLCoderElement(key: box.key, isStringBoxCDATA: isStringBoxCDATA, box: box.element),
            ],
            attributes: attributes
        )
    }

    init(key: String, isStringBoxCDATA isCDATA: Bool, box: KeyedBox, attributes: [Attribute] = []) {
        var elements: [XMLCoderElement] = []

        for (key, box) in box.elements {
            let fail = {
                preconditionFailure("Unclassified box: \(type(of: box))")
            }

            switch box {
            case let sharedUnkeyedBox as SharedBox<UnkeyedBox>:
                let box = sharedUnkeyedBox.unboxed
                elements.append(contentsOf: box.map {
                    XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: $0)
                })
            case let unkeyedBox as UnkeyedBox:
                // This basically injects the unkeyed children directly into self:
                elements.append(contentsOf: unkeyedBox.map {
                    XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: $0)
                })
            case let sharedKeyedBox as SharedBox<KeyedBox>:
                let box = sharedKeyedBox.unboxed
                elements.append(XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: box))
            case let keyedBox as KeyedBox:
                elements.append(XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: keyedBox))
            case let simpleBox as SimpleBox:
                elements.append(XMLCoderElement(key: key, isStringBoxCDATA: isCDATA, box: simpleBox))
            default:
                fail()
            }
        }

        let attributes: [Attribute] = attributes + box.attributes.compactMap { key, box in
            guard let value = box.xmlString else {
                return nil
            }
            return Attribute(key: key, value: value)
        }

        self.init(key: key, elements: elements, attributes: attributes)
    }

    init(key: String, isStringBoxCDATA: Bool, box: SimpleBox) {
        if isStringBoxCDATA, let stringBox = box as? StringBox {
            self.init(key: key, cdataValue: stringBox.unboxed)
        } else if let value = box.xmlString {
            self.init(key: key, stringValue: value)
        } else {
            self.init(key: key)
        }
    }

    init(key: String, isStringBoxCDATA isCDATA: Bool, box: Box, attributes: [Attribute] = []) {
        switch box {
        case let sharedUnkeyedBox as SharedBox<UnkeyedBox>:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: sharedUnkeyedBox.unboxed, attributes: attributes)
        case let sharedKeyedBox as SharedBox<KeyedBox>:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: sharedKeyedBox.unboxed, attributes: attributes)
        case let sharedChoiceBox as SharedBox<ChoiceBox>:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: sharedChoiceBox.unboxed, attributes: attributes)
        case let unkeyedBox as UnkeyedBox:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: unkeyedBox, attributes: attributes)
        case let keyedBox as KeyedBox:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: keyedBox, attributes: attributes)
        case let choiceBox as ChoiceBox:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: choiceBox, attributes: attributes)
        case let simpleBox as SimpleBox:
            self.init(key: key, isStringBoxCDATA: isCDATA, box: simpleBox)
        case let box:
            preconditionFailure("Unclassified box: \(type(of: box))")
        }
    }
}

extension XMLCoderElement {
    func isWhitespaceWithNoElements() -> Bool {
        let stringValueIsWhitespaceOrNil = stringValue?.isAllWhitespace() ?? true
        return self.key == "" && stringValueIsWhitespaceOrNil && self.elements.isEmpty
    }
}
