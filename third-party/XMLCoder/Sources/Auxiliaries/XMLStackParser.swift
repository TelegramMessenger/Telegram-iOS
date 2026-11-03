// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/14/17.
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

class XMLStackParser: NSObject {
    var root: XMLCoderElement?
    private var stack: [XMLCoderElement] = []
    private let trimValueWhitespaces: Bool
    private let removeWhitespaceElements: Bool

    init(trimValueWhitespaces: Bool = true, removeWhitespaceElements: Bool = false) {
        self.trimValueWhitespaces = trimValueWhitespaces
        self.removeWhitespaceElements = removeWhitespaceElements
        super.init()
    }

    static func parse(
        with data: Data,
        errorContextLength length: UInt,
        shouldProcessNamespaces: Bool,
        trimValueWhitespaces: Bool,
        removeWhitespaceElements: Bool
    ) throws -> Box {
        let parser = XMLStackParser(trimValueWhitespaces: trimValueWhitespaces,
                                    removeWhitespaceElements: removeWhitespaceElements)

        let node = try parser.parse(
            with: data,
            errorContextLength: length,
            shouldProcessNamespaces: shouldProcessNamespaces
        )

        return node.transformToBoxTree()
    }

    func parse(
        with data: Data,
        errorContextLength: UInt,
        shouldProcessNamespaces: Bool
    ) throws -> XMLCoderElement {
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = shouldProcessNamespaces
        xmlParser.delegate = self

        guard !xmlParser.parse() || root == nil else {
            return root!
        }

        guard let error = xmlParser.parserError else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "The given data could not be parsed into XML."
            ))
        }

        // `lineNumber` isn't 0-indexed, so 0 is an invalid value for context
        guard errorContextLength > 0 && xmlParser.lineNumber > 0 else {
            throw error
        }

        let string = String(data: data, encoding: .utf8) ?? ""
        let lines = string.split(separator: "\n")
        var errorPosition = 0
        let offset = Int(errorContextLength / 2)
        for i in 0..<xmlParser.lineNumber - 1 {
            errorPosition += lines[i].count
        }
        errorPosition += xmlParser.columnNumber

        var lowerBoundIndex = 0
        if errorPosition - offset > 0 {
            lowerBoundIndex = errorPosition - offset
        }

        var upperBoundIndex = string.count
        if errorPosition + offset < string.count {
            upperBoundIndex = errorPosition + offset
        }

        let lowerBound = String.Index(utf16Offset: lowerBoundIndex, in: string)
        let upperBound = String.Index(utf16Offset: upperBoundIndex, in: string)

        let context = string[lowerBound..<upperBound]

        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [],
            debugDescription: """
            \(error.localizedDescription) \
            at line \(xmlParser.lineNumber), column \(xmlParser.columnNumber):
            `\(context)`
            """,
            underlyingError: error
        ))
    }

    func withCurrentElement(_ body: (inout XMLCoderElement) throws -> ()) rethrows {
        guard !stack.isEmpty else {
            return
        }
        try body(&stack[stack.count - 1])
    }

    func trimWhitespacesIfNeeded(_ string: String) -> String {
        return trimValueWhitespaces
            ? string.trimmingCharacters(in: .whitespacesAndNewlines)
            : string
    }
}

extension XMLStackParser: XMLParserDelegate {
    func parserDidStartDocument(_: XMLParser) {
        root = nil
        stack = []
    }

    func parser(_: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName: String?,
                attributes attributeDict: [String: String] = [:])
    {
        let attributes = attributeDict.map { key, value in
            XMLCoderElement.Attribute(key: key, value: value)
        }
        let element = XMLCoderElement(key: elementName, attributes: attributes)
        stack.append(element)
    }

    func parser(_: XMLParser,
                didEndElement _: String,
                namespaceURI _: String?,
                qualifiedName _: String?)
    {
        guard var element = stack.popLast() else {
            return
        }
        if trimValueWhitespaces && element.containsTextNodes {
            element.trimTextNodes()
        }

        let updatedElement = removeWhitespaceElements ? elementWithFilteredElements(element: element) : element

        withCurrentElement { currentElement in
            currentElement.append(element: updatedElement)
        }

        if stack.isEmpty {
            root = updatedElement
        }
    }

    func elementWithFilteredElements(element: XMLCoderElement) -> XMLCoderElement {
        var hasWhitespaceElements = false
        var hasNonWhitespaceElements = false
        var filteredElements: [XMLCoderElement] = []
        for ele in element.elements {
            if ele.isWhitespaceWithNoElements() {
                hasWhitespaceElements = true
            } else {
                hasNonWhitespaceElements = true
                filteredElements.append(ele)
            }
        }

        if hasWhitespaceElements && hasNonWhitespaceElements {
            return XMLCoderElement(key: element.key, elements: filteredElements, attributes: element.attributes)
        }
        return element
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        let processedString = trimWhitespacesIfNeeded(string)
        guard processedString.count > 0, string.count != 0 else {
            return
        }

        withCurrentElement { currentElement in
            currentElement.append(string: string)
        }
    }

    func parser(_: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else {
            return
        }

        withCurrentElement { currentElement in
            currentElement.append(cdata: string)
        }
    }
}
