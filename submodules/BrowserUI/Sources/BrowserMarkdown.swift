import Foundation
import UIKit
import TelegramCore
import AccountContext
import InstantPageUI
import TextFormat

private let markdownPresentationIntentAttribute = NSAttributedString.Key("NSPresentationIntent")
private let markdownInlinePresentationIntentAttribute = NSAttributedString.Key("NSInlinePresentationIntent")
private let markdownLinkAttribute = NSAttributedString.Key("NSLink")
private let markdownImageURLAttribute = NSAttributedString.Key("NSImageURL")
private let markdownAlternateDescriptionAttribute = NSAttributedString.Key("NSAlternateDescription")

@available(iOS 15.0, *)
private let markdownSoftBreakInlineIntent = InlinePresentationIntent(rawValue: 1 << 6)
@available(iOS 15.0, *)
private let markdownHardBreakInlineIntent = InlinePresentationIntent(rawValue: 1 << 7)
@available(iOS 15.0, *)
private let markdownInlineHTMLInlineIntent = InlinePresentationIntent(rawValue: 1 << 8)

private let markdownDefaultBlockImageDimensions = PixelDimensions(width: 1200, height: 900)
private let markdownDefaultInlineImageDimensions = PixelDimensions(width: 18, height: 18)
private let markdownImageParsingEnabled = false
private let markdownRawHTMLTagRegex = try! NSRegularExpression(pattern: #"</?([A-Za-z][A-Za-z0-9:-]*)\b[^>]*?>"#)
private let markdownFormulaPlaceholderRegex = try! NSRegularExpression(pattern: #"TGMDMATH\d+TGMD"#)
private let markdownVoidHTMLTags: Set<String> = [
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr"
]

private struct MarkdownSafetyLimits {
    let maxFileSize = 524_288
    let maxLineLength = 32_768
    let maxBlockquoteDepth = 64
    let maxListIndent = 96
    let maxRawHTMLTagCount = 8_000
    let maxRawHTMLNestingDepth = 64
    let maxAttributedStringLength = 400_000
    let maxAttributeRuns = 20_000
    let maxPresentationIntentDepth = 128
    let maxIntentNodes = 10_000
    let maxEmittedBlocks = 5_000
    let maxTableColumns = 32
    let maxTableCells = 2_000
    let maxMediaItems = 100
    let maxInlineHTMLStyleDepth = 32
    let maxDataImageBytes = 2_097_152
    let maxDataImagePixelCount = 12_000_000
    let maxFormulas = 200
    let maxFormulaSourceCharacters = 20_000
    let maxInlineFormulaLength = 256
    let maxBlockFormulaLength = 4_096
}

private let markdownSafetyLimits = MarkdownSafetyLimits()

private final class MarkdownConversionBudget {
    let limits: MarkdownSafetyLimits

    private(set) var isExceeded = false

    private var attributeRunCount = 0
    private var intentNodeCount = 0
    private var tableCellCount = 0
    private var mediaItemCount = 0

    init(limits: MarkdownSafetyLimits) {
        self.limits = limits
    }

    @discardableResult
    func fail() -> Bool {
        self.isExceeded = true
        return false
    }

    @discardableResult
    func registerAttributedStringLength(_ length: Int) -> Bool {
        guard length <= self.limits.maxAttributedStringLength else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerAttributeRun() -> Bool {
        self.attributeRunCount += 1
        guard self.attributeRunCount <= self.limits.maxAttributeRuns else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerPresentationIntentDepth(_ depth: Int) -> Bool {
        guard depth <= self.limits.maxPresentationIntentDepth else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerIntentNode() -> Bool {
        self.intentNodeCount += 1
        guard self.intentNodeCount <= self.limits.maxIntentNodes else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerBlockDepth(_ depth: Int) -> Bool {
        guard depth <= self.limits.maxPresentationIntentDepth else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerTableColumns(_ count: Int) -> Bool {
        guard count <= self.limits.maxTableColumns else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerTableCells(_ count: Int) -> Bool {
        self.tableCellCount += count
        guard self.tableCellCount <= self.limits.maxTableCells else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerMediaItem() -> Bool {
        self.mediaItemCount += 1
        guard self.mediaItemCount <= self.limits.maxMediaItems else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func registerInlineHTMLStyleDepth(_ depth: Int) -> Bool {
        guard depth <= self.limits.maxInlineHTMLStyleDepth else {
            return self.fail()
        }
        return true
    }

    @discardableResult
    func validateFinalBlocks(_ blocks: [InstantPageBlock]) -> Bool {
        var count = 0
        return self.validate(blocks: blocks, depth: 0, count: &count)
    }

    private func validate(blocks: [InstantPageBlock], depth: Int, count: inout Int) -> Bool {
        guard self.registerBlockDepth(depth) else {
            return false
        }
        for block in blocks {
            count += 1
            guard count <= self.limits.maxEmittedBlocks else {
                return self.fail()
            }
            switch block {
            case let .list(items, _):
                for item in items {
                    if !self.validate(listItem: item, depth: depth + 1, count: &count) {
                        return false
                    }
                }
            case let .details(_, nestedBlocks, _):
                if !self.validate(blocks: nestedBlocks, depth: depth + 1, count: &count) {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

    private func validate(listItem: InstantPageListItem, depth: Int, count: inout Int) -> Bool {
        guard self.registerBlockDepth(depth) else {
            return false
        }
        if case let .blocks(blocks, _, _) = listItem {
            return self.validate(blocks: blocks, depth: depth + 1, count: &count)
        } else {
            return true
        }
    }
}

private struct MarkdownPageResult {
    let blocks: [InstantPageBlock]
    let media: [EngineMedia.Id: EngineRawMedia]
}

private enum MarkdownFormulaMode {
    case inline
    case block
}

private struct MarkdownFormulaDescriptor {
    let placeholder: String
    let latex: String
    let mode: MarkdownFormulaMode
}

private struct MarkdownPreparedSource {
    let text: String
    let formulasByPlaceholder: [String: MarkdownFormulaDescriptor]
}

private enum MarkdownInlineTextSegment {
    case plain(String)
    case formula(MarkdownFormulaDescriptor)
}

private enum MarkdownInlineFragment {
    case richText(RichText)
    case formula(MarkdownFormulaDescriptor, RichText)
    case image(MarkdownResolvedImage)
}

private struct MarkdownInlineContent {
    let fragments: [MarkdownInlineFragment]
    
    var richText: RichText {
        var result: [RichText] = []
        result.reserveCapacity(self.fragments.count)
        
        for fragment in self.fragments {
            switch fragment {
            case let .richText(text):
                result.append(text)
            case let .formula(_, text):
                result.append(text)
            case let .image(image):
                var text: RichText = .image(id: image.mediaId, dimensions: image.inlineDimensions)
                if let linkUrl = image.linkUrl {
                    text = .url(text: text, url: linkUrl, webpageId: nil)
                }
                result.append(text)
            }
        }
        
        return markdownCompact(result)
    }

    var standaloneBlockFormula: MarkdownFormulaDescriptor? {
        var result: MarkdownFormulaDescriptor?

        for fragment in self.fragments {
            switch fragment {
            case let .richText(text):
                if !markdownIsWhitespaceOnly(text) {
                    return nil
                }
            case let .formula(descriptor, _):
                guard descriptor.mode == .block else {
                    return nil
                }
                if result != nil {
                    return nil
                }
                result = descriptor
            case .image:
                return nil
            }
        }

        return result
    }
    
    var standaloneImage: MarkdownResolvedImage? {
        var result: MarkdownResolvedImage?
        
        for fragment in self.fragments {
            switch fragment {
            case let .richText(text):
                if !markdownIsWhitespaceOnly(text) {
                    return nil
                }
            case .formula:
                return nil
            case let .image(image):
                if result != nil {
                    return nil
                }
                result = image
            }
        }
        
        return result
    }
}

private struct MarkdownResolvedImage {
    let mediaId: EngineMedia.Id
    let inlineDimensions: PixelDimensions
    let caption: InstantPageCaption
    let linkUrl: String?
}

private enum MarkdownResolvedImageSource {
    case remote(String)
    case data(Data, PixelDimensions)
    case unsupported
}

private enum MarkdownTaskListState {
    case unchecked
    case checked
}

private final class MarkdownConversionContext {
    private let context: AccountContext
    fileprivate let documentURL: URL?
    fileprivate let formulasByPlaceholder: [String: MarkdownFormulaDescriptor]
    fileprivate let budget: MarkdownConversionBudget
    private var nextRemoteMediaId: Int64 = 0
    private var nextLocalMediaId: Int64 = 0

    private(set) var media: [EngineMedia.Id: EngineRawMedia] = [:]

    init(context: AccountContext, documentURL: URL?, formulasByPlaceholder: [String: MarkdownFormulaDescriptor], budget: MarkdownConversionBudget) {
        self.context = context
        self.documentURL = documentURL
        self.formulasByPlaceholder = formulasByPlaceholder
        self.budget = budget
    }

    func makePageResult(blocks: [InstantPageBlock]) -> MarkdownPageResult {
        return MarkdownPageResult(blocks: blocks, media: self.media)
    }

    func resolveImage(attributes: [NSAttributedString.Key: Any]) -> MarkdownResolvedImage? {
        guard markdownImageParsingEnabled else {
            return nil
        }
        guard let imageUrl = markdownImageURL(attributes: attributes) else {
            return nil
        }
        
        let inlineDimensions = markdownInlineImageDimensions(attributes: attributes)
        let caption = markdownImageCaption(markdownAlternateDescription(attributes: attributes))
        let linkUrl = markdownLink(attributes: attributes, documentURL: self.documentURL)
        
        switch markdownResolveImageSource(imageUrl, limits: self.budget.limits) {
        case let .remote(url):
            guard self.budget.registerMediaItem() else {
                return nil
            }
            let mediaId = self.nextMediaId(namespace: Namespaces.Media.CloudImage)
            self.media[mediaId] = TelegramMediaImage(
                imageId: mediaId,
                representations: [
                    TelegramMediaImageRepresentation(
                        dimensions: markdownDefaultBlockImageDimensions,
                        resource: InstantPageExternalMediaResource(url: url),
                        progressiveSizes: [],
                        immediateThumbnailData: nil
                    )
                ],
                immediateThumbnailData: nil,
                reference: nil,
                partialReference: nil,
                flags: []
            )
            return MarkdownResolvedImage(
                mediaId: mediaId,
                inlineDimensions: inlineDimensions,
                caption: caption,
                linkUrl: linkUrl
            )
        case let .data(data, dimensions):
            guard self.budget.registerMediaItem() else {
                return nil
            }
            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.count), isSecretRelated: false)
            self.context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data)
            
            let mediaId = self.nextMediaId(namespace: Namespaces.Media.LocalImage)
            self.media[mediaId] = TelegramMediaImage(
                imageId: mediaId,
                representations: [
                    TelegramMediaImageRepresentation(
                        dimensions: dimensions,
                        resource: resource,
                        progressiveSizes: [],
                        immediateThumbnailData: nil
                    )
                ],
                immediateThumbnailData: nil,
                reference: nil,
                partialReference: nil,
                flags: []
            )
            return MarkdownResolvedImage(
                mediaId: mediaId,
                inlineDimensions: inlineDimensions,
                caption: caption,
                linkUrl: linkUrl
            )
        case .unsupported:
            return nil
        }
    }
    
    private func nextMediaId(namespace: Int32) -> EngineMedia.Id {
        switch namespace {
        case Namespaces.Media.LocalImage:
            self.nextLocalMediaId += 1
            return EngineMedia.Id(namespace: namespace, id: self.nextLocalMediaId)
        default:
            self.nextRemoteMediaId += 1
            return EngineMedia.Id(namespace: namespace, id: self.nextRemoteMediaId)
        }
    }
}

private func markdownPassesPreflight(data: Data, limits: MarkdownSafetyLimits) -> Bool {
    guard data.count <= limits.maxFileSize else {
        return false
    }
    guard let text = markdownDecodedSourceText(data) else {
        return false
    }
    return markdownPassesPreflight(text: text, limits: limits)
}

private func markdownDecodedSourceText(_ data: Data) -> String? {
    if let text = String(data: data, encoding: .utf8) {
        return text
    }
    if data.starts(with: [0xff, 0xfe]) {
        return String(data: data, encoding: .utf16LittleEndian)
    }
    if data.starts(with: [0xfe, 0xff]) {
        return String(data: data, encoding: .utf16BigEndian)
    }
    return nil
}

private func markdownPassesPreflight(text: String, limits: MarkdownSafetyLimits) -> Bool {
    var activeFence: Character?
    var htmlTagCount = 0
    var htmlDepth = 0

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
        var line = String(rawLine)
        if line.hasSuffix("\r") {
            line.removeLast()
        }

        if (line as NSString).length > limits.maxLineLength {
            return false
        }

        if let fenceMarker = markdownFenceMarker(in: line) {
            if activeFence == fenceMarker {
                activeFence = nil
            } else {
                activeFence = fenceMarker
            }
            continue
        }

        if activeFence != nil {
            continue
        }

        if markdownBlockquoteDepth(in: line) > limits.maxBlockquoteDepth {
            return false
        }
        if markdownIndentWidth(in: line) > limits.maxListIndent {
            return false
        }
        if !markdownScanRawHTMLTags(in: line, limits: limits, tagCount: &htmlTagCount, depth: &htmlDepth) {
            return false
        }
    }

    return true
}

private func markdownFenceMarker(in line: String) -> Character? {
    let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
    guard let marker = trimmed.first, marker == "`" || marker == "~" else {
        return nil
    }
    var count = 0
    var index = trimmed.startIndex
    while index < trimmed.endIndex, trimmed[index] == marker {
        count += 1
        index = trimmed.index(after: index)
    }
    return count >= 3 ? marker : nil
}

private func markdownBlockquoteDepth(in line: String) -> Int {
    var depth = 0
    var index = line.startIndex

    while index < line.endIndex {
        switch line[index] {
        case " ", "\t":
            index = line.index(after: index)
        case ">":
            depth += 1
            index = line.index(after: index)
            if index < line.endIndex, (line[index] == " " || line[index] == "\t") {
                index = line.index(after: index)
            }
        default:
            return depth
        }
    }

    return depth
}

private func markdownIndentWidth(in line: String) -> Int {
    var width = 0
    for character in line {
        switch character {
        case " ":
            width += 1
        case "\t":
            width += 4
        default:
            return width
        }
    }
    return width
}

private func markdownScanRawHTMLTags(in line: String, limits: MarkdownSafetyLimits, tagCount: inout Int, depth: inout Int) -> Bool {
    let nsLine = line as NSString
    let matches = markdownRawHTMLTagRegex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

    for match in matches {
        tagCount += 1
        guard tagCount <= limits.maxRawHTMLTagCount else {
            return false
        }

        let tagText = nsLine.substring(with: match.range)
        let tagName = nsLine.substring(with: match.range(at: 1)).lowercased()
        let lowercasedTag = tagText.lowercased()

        if lowercasedTag.hasPrefix("</") {
            depth = max(0, depth - 1)
        } else if !lowercasedTag.hasSuffix("/>") && !markdownVoidHTMLTags.contains(tagName) {
            depth += 1
            guard depth <= limits.maxRawHTMLNestingDepth else {
                return false
            }
        }
    }

    return true
}

private func markdownPreparedSource(text: String, limits: MarkdownSafetyLimits) -> MarkdownPreparedSource {
    let lines = markdownLinesPreservingEndings(text)

    var activeFence: Character?
    var formulasByPlaceholder: [String: MarkdownFormulaDescriptor] = [:]
    var acceptedFormulaCount = 0
    var totalFormulaCharacters = 0
    var nextPlaceholderIndex = 0
    var result = ""

    var lineIndex = 0
    while lineIndex < lines.count {
        let line = lines[lineIndex]
        let (content, _) = markdownLineContentAndEnding(line)

        if let fenceMarker = markdownFenceMarker(in: content) {
            if activeFence == fenceMarker {
                activeFence = nil
            } else {
                activeFence = fenceMarker
            }
            result.append(contentsOf: line)
            lineIndex += 1
            continue
        }

        if activeFence != nil {
            result.append(contentsOf: line)
            lineIndex += 1
            continue
        }

        if let replacement = markdownBlockFormulaReplacement(
            in: lines,
            startLineIndex: lineIndex,
            limits: limits,
            acceptedFormulaCount: &acceptedFormulaCount,
            totalFormulaCharacters: &totalFormulaCharacters,
            nextPlaceholderIndex: &nextPlaceholderIndex
        ) {
            result.append(contentsOf: replacement.replacement)
            formulasByPlaceholder[replacement.descriptor.placeholder] = replacement.descriptor
            lineIndex = replacement.nextLineIndex
            continue
        }

        let processedLine = markdownReplacingInlineFormulas(
            in: line,
            limits: limits,
            acceptedFormulaCount: &acceptedFormulaCount,
            totalFormulaCharacters: &totalFormulaCharacters,
            nextPlaceholderIndex: &nextPlaceholderIndex,
            formulasByPlaceholder: &formulasByPlaceholder
        )
        result.append(contentsOf: processedLine)
        lineIndex += 1
    }

    return MarkdownPreparedSource(text: result, formulasByPlaceholder: formulasByPlaceholder)
}

private func markdownLinesPreservingEndings(_ text: String) -> [String] {
    guard !text.isEmpty else {
        return []
    }

    var result: [String] = []
    var lineStart = text.startIndex
    var index = text.startIndex

    while index < text.endIndex {
        if text[index] == "\n" {
            let nextIndex = text.index(after: index)
            result.append(String(text[lineStart ..< nextIndex]))
            lineStart = nextIndex
        }
        index = text.index(after: index)
    }

    if lineStart < text.endIndex {
        result.append(String(text[lineStart...]))
    }

    return result
}

private func markdownLineContentAndEnding(_ line: String) -> (content: String, ending: String) {
    if line.hasSuffix("\r\n") {
        return (String(line.dropLast(2)), "\r\n")
    } else if line.hasSuffix("\n") {
        return (String(line.dropLast()), "\n")
    } else {
        return (line, "")
    }
}

private func markdownFormulaPlaceholder(_ index: Int) -> String {
    return "TGMDMATH\(index)TGMD"
}

private func markdownAcceptedFormulaDescriptor(
    latex: String,
    mode: MarkdownFormulaMode,
    limits: MarkdownSafetyLimits,
    acceptedFormulaCount: inout Int,
    totalFormulaCharacters: inout Int,
    nextPlaceholderIndex: inout Int
) -> MarkdownFormulaDescriptor? {
    let normalizedLatex: String
    switch mode {
    case .inline:
        normalizedLatex = latex
    case .block:
        normalizedLatex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard !normalizedLatex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }

    let latexLength = (normalizedLatex as NSString).length
    let maxLength = mode == .inline ? limits.maxInlineFormulaLength : limits.maxBlockFormulaLength
    guard latexLength <= maxLength else {
        return nil
    }
    guard acceptedFormulaCount < limits.maxFormulas else {
        return nil
    }
    guard totalFormulaCharacters + latexLength <= limits.maxFormulaSourceCharacters else {
        return nil
    }

    let placeholder = markdownFormulaPlaceholder(nextPlaceholderIndex)
    nextPlaceholderIndex += 1
    acceptedFormulaCount += 1
    totalFormulaCharacters += latexLength
    return MarkdownFormulaDescriptor(placeholder: placeholder, latex: normalizedLatex, mode: mode)
}

private func markdownBlockFormulaReplacement(
    in lines: [String],
    startLineIndex: Int,
    limits: MarkdownSafetyLimits,
    acceptedFormulaCount: inout Int,
    totalFormulaCharacters: inout Int,
    nextPlaceholderIndex: inout Int
) -> (replacement: String, nextLineIndex: Int, descriptor: MarkdownFormulaDescriptor)? {
    guard startLineIndex >= 0, startLineIndex < lines.count else {
        return nil
    }

    let (content, _) = markdownLineContentAndEnding(lines[startLineIndex])
    let indentation = String(content.prefix { $0 == " " || $0 == "\t" })
    let trimmedStart = content.drop(while: { $0 == " " || $0 == "\t" })

    let opener: String
    let closer: String
    if trimmedStart.hasPrefix("$$") {
        opener = "$$"
        closer = "$$"
    } else if trimmedStart.hasPrefix("\\[") {
        opener = "\\["
        closer = "\\]"
    } else {
        return nil
    }

    let openerContent = String(trimmedStart.dropFirst(opener.count))
    // Block opener must be exactly `$$` (not `$$$`); a `$$$…` line is not a block and
    // falls through to inline handling.
    if opener == "$$", openerContent.first == "$" {
        return nil
    }
    var latex = ""

    if let closeRange = markdownFirstUnescapedRange(of: closer, in: openerContent, from: openerContent.startIndex) {
        let trailing = String(openerContent[closeRange.upperBound...])
        guard trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        latex = String(openerContent[..<closeRange.lowerBound])
        guard let descriptor = markdownAcceptedFormulaDescriptor(
            latex: latex,
            mode: .block,
            limits: limits,
            acceptedFormulaCount: &acceptedFormulaCount,
            totalFormulaCharacters: &totalFormulaCharacters,
            nextPlaceholderIndex: &nextPlaceholderIndex
        ) else {
            return nil
        }
        let (_, ending) = markdownLineContentAndEnding(lines[startLineIndex])
        return (indentation + descriptor.placeholder + ending, startLineIndex + 1, descriptor)
    }

    // Reached only when there is no closer on the opener line (multi-line form).
    // A multi-line block opener must be a bare `$$` line; `$$ content` is not a block.
    if opener == "$$", !openerContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return nil
    }
    let (_, openerEnding) = markdownLineContentAndEnding(lines[startLineIndex])
    latex.append(contentsOf: openerContent)
    latex.append(contentsOf: openerEnding)

    var currentIndex = startLineIndex + 1
    while currentIndex < lines.count {
        let (nextContent, nextEnding) = markdownLineContentAndEnding(lines[currentIndex])
        if let closeRange = markdownFirstUnescapedRange(of: closer, in: nextContent, from: nextContent.startIndex) {
            let trailing = String(nextContent[closeRange.upperBound...])
            guard trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            latex.append(contentsOf: String(nextContent[..<closeRange.lowerBound]))
            guard let descriptor = markdownAcceptedFormulaDescriptor(
                latex: latex,
                mode: .block,
                limits: limits,
                acceptedFormulaCount: &acceptedFormulaCount,
                totalFormulaCharacters: &totalFormulaCharacters,
                nextPlaceholderIndex: &nextPlaceholderIndex
            ) else {
                return nil
            }
            return (indentation + descriptor.placeholder + nextEnding, currentIndex + 1, descriptor)
        } else {
            latex.append(contentsOf: nextContent)
            latex.append(contentsOf: nextEnding)
        }
        currentIndex += 1
    }

    return nil
}

private func markdownReplacingInlineFormulas(
    in line: String,
    limits: MarkdownSafetyLimits,
    acceptedFormulaCount: inout Int,
    totalFormulaCharacters: inout Int,
    nextPlaceholderIndex: inout Int,
    formulasByPlaceholder: inout [String: MarkdownFormulaDescriptor]
) -> String {
    let (content, ending) = markdownLineContentAndEnding(line)
    guard !content.isEmpty else {
        return line
    }

    var result = ""
    var index = content.startIndex
    var activeCodeDelimiterLength: Int?

    while index < content.endIndex {
        if content[index] == "`" {
            let delimiterEnd = markdownIndex(afterRepeating: "`", in: content, from: index)
            let delimiterLength = content.distance(from: index, to: delimiterEnd)
            result.append(contentsOf: content[index ..< delimiterEnd])
            if activeCodeDelimiterLength == delimiterLength {
                activeCodeDelimiterLength = nil
            } else {
                activeCodeDelimiterLength = delimiterLength
            }
            index = delimiterEnd
            continue
        }

        if activeCodeDelimiterLength != nil {
            result.append(content[index])
            index = content.index(after: index)
            continue
        }

        if content[index] == "\\", !markdownIsEscaped(content, at: index), let nextIndex = markdownIndex(content, offsetBy: 1, from: index), nextIndex < content.endIndex, content[nextIndex] == "(" {
            let bodyStart = content.index(after: nextIndex)
            if let closeRange = markdownFirstUnescapedRange(of: "\\)", in: content, from: bodyStart) {
                let latex = String(content[bodyStart ..< closeRange.lowerBound])
                if let descriptor = markdownAcceptedFormulaDescriptor(
                    latex: latex,
                    mode: .inline,
                    limits: limits,
                    acceptedFormulaCount: &acceptedFormulaCount,
                    totalFormulaCharacters: &totalFormulaCharacters,
                    nextPlaceholderIndex: &nextPlaceholderIndex
                ) {
                    result.append(contentsOf: descriptor.placeholder)
                    formulasByPlaceholder[descriptor.placeholder] = descriptor
                    index = closeRange.upperBound
                    continue
                }
            }
        }

        if content[index] == "$", !markdownIsEscaped(content, at: index) {
            // Outer boundary before the opener: line start, or a non-alphanumeric char.
            // (Rejects `cost$5$total`, the `$` after `5` in `$5-$10`, etc.)
            if index > content.startIndex {
                let beforeOpener = content[content.index(before: index)]
                if beforeOpener.isLetter || beforeOpener.isNumber {
                    result.append(content[index])
                    index = content.index(after: index)
                    continue
                }
            }
            // Opener: 1 or 2 leading `$` (a 3rd `$` becomes inner content).
            let openerRunEnd = markdownIndex(afterRepeating: "$", in: content, from: index)
            let openerCount = min(2, content.distance(from: index, to: openerRunEnd))
            let bodyStart = content.index(index, offsetBy: openerCount)
            // Inner boundary after the opener: must exist and be non-whitespace.
            guard bodyStart < content.endIndex, !content[bodyStart].isWhitespace else {
                result.append(content[index])
                index = content.index(after: index)
                continue
            }
            let closerPattern = String(repeating: "$", count: openerCount)
            var searchIndex = bodyStart
            var matchedRange: Range<String.Index>?
            while let closeRange = markdownFirstUnescapedRange(of: closerPattern, in: content, from: searchIndex) {
                // Inner boundary before the closer: non-whitespace.
                let beforeCloser = content[content.index(before: closeRange.lowerBound)]
                if beforeCloser.isWhitespace {
                    searchIndex = closeRange.upperBound
                    continue
                }
                // Outer boundary after the closer: line end, or a non-alphanumeric char.
                if closeRange.upperBound < content.endIndex {
                    let afterCloser = content[closeRange.upperBound]
                    if afterCloser.isLetter || afterCloser.isNumber {
                        searchIndex = closeRange.upperBound
                        continue
                    }
                }
                matchedRange = closeRange
                break
            }
            if let matchedRange {
                let latex = String(content[bodyStart ..< matchedRange.lowerBound])
                if let descriptor = markdownAcceptedFormulaDescriptor(
                    latex: latex,
                    mode: .inline,
                    limits: limits,
                    acceptedFormulaCount: &acceptedFormulaCount,
                    totalFormulaCharacters: &totalFormulaCharacters,
                    nextPlaceholderIndex: &nextPlaceholderIndex
                ) {
                    result.append(contentsOf: descriptor.placeholder)
                    formulasByPlaceholder[descriptor.placeholder] = descriptor
                    index = matchedRange.upperBound
                    continue
                }
            }
        }

        result.append(content[index])
        index = content.index(after: index)
    }

    result.append(contentsOf: ending)
    return result
}

private func markdownFirstUnescapedRange(of pattern: String, in text: String, from startIndex: String.Index) -> Range<String.Index>? {
    guard !pattern.isEmpty, startIndex <= text.endIndex else {
        return nil
    }

    var searchIndex = startIndex
    while searchIndex < text.endIndex {
        guard let range = text.range(of: pattern, range: searchIndex ..< text.endIndex) else {
            return nil
        }
        if !markdownIsEscaped(text, at: range.lowerBound) {
            return range
        }
        searchIndex = range.upperBound
    }
    return nil
}

private func markdownIsEscaped(_ text: String, at index: String.Index) -> Bool {
    guard index > text.startIndex else {
        return false
    }

    var slashCount = 0
    var currentIndex = text.index(before: index)
    while true {
        if text[currentIndex] == "\\" {
            slashCount += 1
        } else {
            break
        }
        guard currentIndex > text.startIndex else {
            break
        }
        currentIndex = text.index(before: currentIndex)
    }

    return slashCount % 2 == 1
}

private func markdownIndex(_ text: String, offsetBy distance: Int, from index: String.Index) -> String.Index? {
    guard distance >= 0 else {
        return nil
    }
    return text.index(index, offsetBy: distance, limitedBy: text.endIndex)
}

private func markdownIndex(afterRepeating character: Character, in text: String, from startIndex: String.Index) -> String.Index {
    var index = startIndex
    while index < text.endIndex, text[index] == character {
        index = text.index(after: index)
    }
    return index
}

func markdownWebpage(context: AccountContext, file: FileMediaReference) -> (webPage: TelegramMediaWebpage, fileURL: URL)? {
    guard #available(iOS 15.0, *) else {
        return nil
    }
    guard let path = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(file.media.resource.id)) else {
        return nil
    }
    let fileURL = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: fileURL) else {
        return nil
    }
    guard let webPage = markdownWebpage(context: context, file: (file, fileURL), data: data) else {
        return nil
    }
    return (webPage, fileURL)
}

public func inputRichTextAttributeFromText(context: AccountContext, text: String) -> RichTextMessageAttribute? {
    guard #available(iOS 15.0, *) else {
        return nil
    }
    guard let data = text.data(using: .utf8) else {
        return nil
    }
    guard let webpage = markdownWebpage(context: context, file: nil, data: data), case let .Loaded(content) = webpage.content, let instantPage = content.instantPage else {
        return nil
    }
    return RichTextMessageAttribute(instantPage: instantPage._parse(), fullInstantPage: nil)
}

// MARK: - Markdown classification (entity-expressible vs. rich layout)

private let markdownBlockHeuristicRegex = try? NSRegularExpression(
    pattern: "(^|\\n)[ \\t]*(#{1,6}[ \\t]|[-*+][ \\t]|\\d{1,9}[.)][ \\t]|-{1,}[ \\t]*(\\n|$))",
    options: []
)

// Cheap necessary-condition pre-filter. A safe over-approximation: if it
// returns false, the text cannot contain a rich-only construct, so the
// expensive markdown parse is skipped and the entity path is used.
private func markdownMightNeedRichLayout(_ text: String) -> Bool {
    // Tables ('|') and images ('![') can appear anywhere on a line. This over-approximates
    // (prose containing '|' also triggers a parse); the parse + block inspection resolves it.
    if text.contains("|") || text.contains("![") {
        return true
    }
    // Math delimiters. Over-approximates (any `$` triggers a parse); the strict
    // detection + gate decide whether a formula block is actually produced.
    if text.contains("$") || text.contains("\\(") || text.contains("\\[") {
        return true
    }
    // Setext H1 heading: a line of '=' underlining the previous line.
    // (Setext H2 dash-underlines are caught by the dash-line branch in the regex.)
    if text.contains("\n=") {
        return true
    }
    // Line-anchored block markers: headings, list items, setext-H2 dash underlines.
    if let regex = markdownBlockHeuristicRegex {
        let range = NSRange(text.startIndex..., in: text)
        if regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
    }
    return false
}

// True when this inline RichText maps onto Telegram message entities.
// Returns false for inline content that forces the rich path (inline image,
// sub/superscript, highlight, formula). Formulas trigger the rich path; casual
// '$' usage is excluded by the strict boundary rule in the detection step, not here.
private func richTextIsEntityExpressible(_ text: RichText) -> Bool {
    switch text {
    case .empty, .plain:
        return true
    case .bold(let inner), .italic(let inner), .underline(let inner), .strikethrough(let inner), .fixed(let inner):
        return richTextIsEntityExpressible(inner)
    case .superscript, .marked, .`subscript`:
        return false
    case .url(let inner, _, _):
        return richTextIsEntityExpressible(inner)
    case .email(let inner, _):
        return richTextIsEntityExpressible(inner)
    case .concat(let items):
        return items.allSatisfy(richTextIsEntityExpressible)
    case .phone(let inner, _):
        return richTextIsEntityExpressible(inner)
    case .image:
        return false
    case .anchor(let inner, _):
        return richTextIsEntityExpressible(inner)
    case .formula:
        return false
    case .textCustomEmoji:
        return true
    case .textAutoEmail(let inner), .textAutoPhone(let inner), .textAutoUrl(let inner), .textBankCard(let inner), .textTonAddress(let inner), .textBotCommand(let inner), .textCashtag(let inner), .textHashtag(let inner), .textMention(let inner), .textSpoiler(let inner):
        return richTextIsEntityExpressible(inner)
    case .textMentionName(let inner, _):
        return richTextIsEntityExpressible(inner)
    case .textDate:
        return false
    case .textButton:
        // No message entity can express a button, so its presence forces the rich path.
        return false
    }
}

private func isEmptyRichText(_ text: RichText) -> Bool {
    switch text {
    case .empty:
        return true
    case .plain(let value):
        return value.isEmpty
    default:
        return false
    }
}

// Block types that do NOT trigger a rich-layout message. Besides the genuinely
// entity-expressible blocks (paragraph/preformatted/blockQuote/anchor), dividers
// are intentionally excluded as triggers too ('---' is too common in casual text).
// Formulas DO trigger the rich path; casual '$' usage is excluded by the strict
// boundary rule in the detection step. Effective rich triggers are therefore
// headings, lists, tables, and formulas.
private func blockIsEntityExpressible(_ block: InstantPageBlock) -> Bool {
    switch block {
    case .paragraph(let text):
        return richTextIsEntityExpressible(text)
    case .preformatted(let text, _):
        return richTextIsEntityExpressible(text)
    case .blockQuote(let blocks, let caption, _):
        guard isEmptyRichText(caption) else { return false }
        return blocks.allSatisfy { child in
            if case let .paragraph(text) = child {
                return richTextIsEntityExpressible(text)
            }
            return false
        }
    case .anchor, .unsupported:
        return true
    case .divider:
        return true
    default:
        return false
    }
}

private func instantPageNeedsRichLayout(_ blocks: [InstantPageBlock]) -> Bool {
    return blocks.contains { !blockIsEntityExpressible($0) }
}

// Rewrites each `ChatTextInputAttributes.customEmoji` run in the attributed
// input as a `[<alt>](tg://emoji?id=<fileId>)` markdown link, leaving all other
// text (and its markdown syntax) verbatim. With no custom emoji present this
// returns `attributedText.string` unchanged, so non-emoji messages are
// unaffected. The marker is intercepted post-parse in markdownInlineContent.
private func markdownSourceInjectingCustomEmojiMarkers(_ attributedText: NSAttributedString) -> String {
    let nsString = attributedText.string as NSString
    var result = ""
    attributedText.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: attributedText.length), options: []) { value, range, _ in
        let substring = nsString.substring(with: range)
        if let attribute = value as? ChatTextInputTextCustomEmojiAttribute {
            // The link text must be non-empty: CommonMark drops `[](url)` (no
            // run carries the link attribute), which would silently lose the
            // emoji. Fall back to a space, matching the reattach helper.
            let alt = substring.isEmpty ? " " : substring
            result += "[\(escapeCustomEmojiMarkdownAlt(alt))](\(customEmojiMarkdownURL(fileId: attribute.fileId)))"
        } else {
            result += substring
        }
    }
    return result
}

// Returns a RichTextMessageAttribute IFF the markdown in `text` produces an
// InstantPage block with no entity equivalent. Returns nil (-> send via the
// regular entity path) for plain text, pre-iOS-15, oversize markdown, or
// markdown that maps cleanly onto entities.
public func richMarkdownAttributeIfNeeded(context: AccountContext, attributedText: NSAttributedString) -> RichTextMessageAttribute? {
    // Custom emoji are rewritten to `[<alt>](tg://emoji?id=...)` link markers
    // before classification + parse; the markers are intercepted back into
    // .textCustomEmoji in markdownInlineContent. A link is entity-expressible,
    // so an emoji-only message still classifies as not-rich (and falls through
    // to the entity path, where its untouched attribute makes a .CustomEmoji
    // entity) — custom emoji alone never forces a rich message.
    let text = markdownSourceInjectingCustomEmojiMarkers(attributedText)
    guard markdownMightNeedRichLayout(text) else {
        return nil
    }
    guard let attribute = inputRichTextAttributeFromText(context: context, text: text) else {
        return nil
    }
    guard instantPageNeedsRichLayout(attribute.instantPage.blocks) else {
        return nil
    }
    return attribute
}

@available(iOS 15.0, *)
private func markdownWebpage(context: AccountContext, file: (file: FileMediaReference, url: URL)?, data: Data) -> TelegramMediaWebpage? {
    let limits = markdownSafetyLimits
    guard markdownPassesPreflight(data: data, limits: limits) else {
        return nil
    }
    guard let sourceText = markdownDecodedSourceText(data) else {
        return nil
    }
    let preparedSource = markdownPreparedSource(text: sourceText, limits: limits)

    let attributedString: NSAttributedString
    do {
        let baseURL: URL?
        if let file {
            baseURL = file.url.deletingLastPathComponent()
        } else {
            baseURL = nil
        }
        attributedString = try NSAttributedString(
            markdown: Data(preparedSource.text.utf8),
            options: .init(),
            baseURL: baseURL
        )
    } catch {
        return nil
    }
    
    let budget = MarkdownConversionBudget(limits: limits)
    let conversionContext = MarkdownConversionContext(context: context, documentURL: file?.url, formulasByPlaceholder: preparedSource.formulasByPlaceholder, budget: budget)
    guard let pageResult = markdownPageResult(from: attributedString, context: conversionContext) else {
        return nil
    }
    // Heading anchors exist for intra-document navigation ([link](#slug)); they are
    // noise in a chat message, where they prepend an invisible block per heading.
    // Only generate them for the document path (file != nil).
    let blocks: [InstantPageBlock]
    if file != nil {
        blocks = markdownBlocksWithGeneratedAnchors(pageResult.blocks)
    } else {
        blocks = pageResult.blocks
    }
    guard !blocks.isEmpty, budget.validateFinalBlocks(blocks) else {
        return nil
    }
    
    var title: String?
    if let file {
        title = markdownTitle(from: blocks, file: file.file, fileURL: file.url)
    }
    let text = markdownFirstParagraphText(from: blocks)
    let instantPage = InstantPage(
        blocks: blocks,
        media: pageResult.media,
        isComplete: true,
        rtl: false,
        url: file?.url.absoluteString ?? "",
        views: nil
    )
    
    return TelegramMediaWebpage(
        webpageId: EngineMedia.Id(namespace: 0, id: 0),
        content: .Loaded(
            TelegramMediaWebpageLoadedContent(
                url: file?.url.absoluteString ?? "",
                displayUrl: file?.url.absoluteString ?? "",
                hash: 0,
                type: "article",
                websiteName: nil,
                title: title,
                text: text,
                embedUrl: nil,
                embedType: nil,
                embedSize: nil,
                duration: nil,
                author: nil,
                isMediaLargeByDefault: nil,
                imageIsVideoCover: false,
                image: nil,
                file: nil,
                story: nil,
                attributes: [],
                instantPage: instantPage
            )
        )
    )
}

@available(iOS 15.0, *)
private func markdownPageResult(from attributedString: NSAttributedString, context: MarkdownConversionContext) -> MarkdownPageResult? {
    guard context.budget.registerAttributedStringLength(attributedString.length) else {
        return nil
    }

    var nodesByIdentity: [Int: MarkdownIntentNode] = [:]
    var rootNodes: [MarkdownIntentNode] = []
    var rootIdentities: Set<Int> = []
    var didAbort = false

    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, stop in
        guard range.length > 0 else {
            return
        }
        guard context.budget.registerAttributeRun() else {
            didAbort = true
            stop.pointee = true
            return
        }
        guard let presentationIntent = attributes[markdownPresentationIntentAttribute] as? PresentationIntent else {
            return
        }
        let components = presentationIntent.components
        guard !components.isEmpty else {
            return
        }
        guard context.budget.registerPresentationIntentDepth(components.count) else {
            didAbort = true
            stop.pointee = true
            return
        }

        var orderedNodes: [MarkdownIntentNode] = []
        for component in components.reversed() {
            let node: MarkdownIntentNode
            if let current = nodesByIdentity[component.identity] {
                node = current
            } else {
                guard context.budget.registerIntentNode() else {
                    didAbort = true
                    stop.pointee = true
                    return
                }
                let created = MarkdownIntentNode(component: component)
                nodesByIdentity[component.identity] = created
                node = created
            }
            orderedNodes.append(node)
        }
        
        if let rootNode = orderedNodes.first, rootIdentities.insert(rootNode.identity).inserted {
            rootNodes.append(rootNode)
        }
        if orderedNodes.count >= 2 {
            for index in 0 ..< (orderedNodes.count - 1) {
                orderedNodes[index].append(child: orderedNodes[index + 1])
            }
        }
        if let leafNode = orderedNodes.last {
            leafNode.append(text: attributedString.attributedSubstring(from: range))
        }
    }
    
    guard !didAbort, !context.budget.isExceeded else {
        return nil
    }
    guard let blocks = markdownBlocks(from: rootNodes, context: context, depth: 0), !context.budget.isExceeded else {
        return nil
    }
    return context.makePageResult(blocks: blocks)
}

private func markdownBlocks(from nodes: [MarkdownIntentNode], context: MarkdownConversionContext, depth: Int) -> [InstantPageBlock]? {
    guard context.budget.registerBlockDepth(depth), !context.budget.isExceeded else {
        return nil
    }

    var result: [InstantPageBlock] = []
    for node in nodes {
        guard let blocks = markdownBlocks(from: node, context: context, depth: depth + 1) else {
            return nil
        }
        result.append(contentsOf: blocks)
        if context.budget.isExceeded {
            return nil
        }
    }
    return result
}

private func markdownBlocks(from node: MarkdownIntentNode, context: MarkdownConversionContext, depth: Int) -> [InstantPageBlock]? {
    guard context.budget.registerBlockDepth(depth), !context.budget.isExceeded else {
        return nil
    }

    switch node.kind {
    case let .table(alignments):
        guard let rows = markdownTableRows(from: node.children, alignments: alignments, context: context, depth: depth + 1) else {
            return nil
        }
        guard !rows.isEmpty else {
            return []
        }
        return [.table(title: .empty, rows: rows, bordered: true, striped: false, compact: false)]
    case let .header(level):
        guard let text = markdownRichText(from: node.attributedText, context: context) else {
            return nil
        }
        guard markdownHasDisplayableContent(text) else {
            return []
        }
        switch level {
        case Int.min ... 1:
            if context.documentURL == nil {
                // Chat message: a single '#' is a normal heading, not a document title.
                return [.heading(text: text, level: 1)]
            } else {
                return [.title(text)]
            }
        default:
            return [.heading(text: text, level: Int32(max(2, min(level, 6))))]
        }
    case .paragraph:
        guard let inlineContent = markdownInlineContent(from: node.attributedText, context: context) else {
            return nil
        }
        if let formula = inlineContent.standaloneBlockFormula {
            return [.formula(latex: formula.latex)]
        }
        if let image = inlineContent.standaloneImage {
            return [
                .image(
                    id: image.mediaId,
                    caption: image.caption,
                    url: image.linkUrl,
                    webpageId: nil,
                    spoiler: false
                )
            ]
        }
        let text = inlineContent.richText
        guard markdownHasDisplayableContent(text) else {
            return []
        }
        return [.paragraph(text)]
    case let .codeBlock(languageHint):
        guard let text = markdownRichText(from: markdownTrimTrailingCodeBlockNewline(node.attributedText), context: context) else {
            return nil
        }
        guard markdownHasDisplayableContent(text) else {
            return []
        }
        return [.preformatted(text: text, language: markdownNormalizedCodeBlockLanguage(languageHint))]
    case .thematicBreak:
        return [.divider]
    case .blockQuote:
        var childBlocks: [InstantPageBlock] = []
        for child in node.children {
            guard let parsed = markdownBlocks(from: child, context: context, depth: depth + 1) else {
                return nil
            }
            childBlocks.append(contentsOf: parsed)
        }
        guard !childBlocks.isEmpty else {
            return []
        }
        return [.blockQuote(blocks: childBlocks, caption: .empty, collapsed: nil)]
    case .orderedList:
        guard let items = markdownListItems(from: node.children, ordered: true, context: context, depth: depth + 1) else {
            return nil
        }
        guard !items.isEmpty else {
            return []
        }
        return [.list(items: items, ordered: true)]
    case .unorderedList:
        guard let items = markdownListItems(from: node.children, ordered: false, context: context, depth: depth + 1) else {
            return nil
        }
        guard !items.isEmpty else {
            return []
        }
        return [.list(items: items, ordered: false)]
    case .listItem(_), .tableHeaderRow, .tableRow, .tableCell(_), .unknown:
        return markdownBlocks(from: node.children, context: context, depth: depth + 1)
    }
}

private func markdownListItems(from nodes: [MarkdownIntentNode], ordered: Bool, context: MarkdownConversionContext, depth: Int) -> [InstantPageListItem]? {
    guard context.budget.registerBlockDepth(depth), !context.budget.isExceeded else {
        return nil
    }

    var result: [InstantPageListItem] = []
    for node in nodes {
        guard case let .listItem(ordinal) = node.kind else {
            continue
        }
        guard var blocks = markdownBlocks(from: node.children, context: context, depth: depth + 1) else {
            return nil
        }
        let taskListState = markdownApplyTaskListMarker(to: &blocks)
        let checked: Bool?
        switch taskListState {
        case .unchecked:
            checked = false
        case .checked:
            checked = true
        case nil:
            checked = nil
        }
        let number: String? = ordered ? "\(ordinal)" : nil
        if blocks.isEmpty {
            if checked != nil || number != nil {
                result.append(.text(.plain(" "), number, checked))
            }
            continue
        }
        if blocks.count == 1, case let .paragraph(text) = blocks[0] {
            if markdownIsWhitespaceOnly(text) && (checked != nil || number != nil) {
                result.append(.text(.plain(" "), number, checked))
            } else {
                result.append(.text(text, number, checked))
            }
        } else {
            result.append(.blocks(blocks, number, checked))
        }
    }
    return result
}

private func markdownApplyTaskListMarker(to blocks: inout [InstantPageBlock]) -> MarkdownTaskListState? {
    guard !blocks.isEmpty, case let .paragraph(text) = blocks[0] else {
        return nil
    }
    guard let (state, strippedText) = markdownStrippingTaskListMarker(from: text) else {
        return nil
    }
    if blocks.count > 1 && markdownIsWhitespaceOnly(strippedText) {
        blocks.removeFirst()
    } else {
        blocks[0] = .paragraph(strippedText)
    }
    return state
}

private func markdownStrippingTaskListMarker(from text: RichText) -> (MarkdownTaskListState, RichText)? {
    guard let (state, markerLength) = markdownTaskListMarker(in: text.plainText) else {
        return nil
    }
    return (state, markdownDroppingPrefixLength(markerLength, from: text))
}

private func markdownTaskListMarker(in plainText: String) -> (MarkdownTaskListState, Int)? {
    switch plainText {
    case _ where plainText.hasPrefix("[ ] "):
        return (.unchecked, 4)
    case "[ ]":
        return (.unchecked, 3)
    case _ where plainText.hasPrefix("[x] "), _ where plainText.hasPrefix("[X] "):
        return (.checked, 4)
    case "[x]", "[X]":
        return (.checked, 3)
    default:
        return nil
    }
}

private func markdownTableRows(from nodes: [MarkdownIntentNode], alignments: [TableHorizontalAlignment], context: MarkdownConversionContext, depth: Int) -> [InstantPageTableRow]? {
    guard context.budget.registerBlockDepth(depth), !context.budget.isExceeded else {
        return nil
    }

    var result: [InstantPageTableRow] = []
    for node in nodes {
        switch node.kind {
        case .tableHeaderRow:
            guard let cells = markdownTableCells(from: node.children, alignments: alignments, header: true, context: context, depth: depth + 1) else {
                return nil
            }
            if !cells.isEmpty {
                result.append(InstantPageTableRow(cells: cells))
            }
        case .tableRow:
            guard let cells = markdownTableCells(from: node.children, alignments: alignments, header: false, context: context, depth: depth + 1) else {
                return nil
            }
            if !cells.isEmpty {
                result.append(InstantPageTableRow(cells: cells))
            }
        default:
            continue
        }
    }
    return context.budget.isExceeded ? nil : result
}

private func markdownTableCells(from nodes: [MarkdownIntentNode], alignments: [TableHorizontalAlignment], header: Bool, context: MarkdownConversionContext, depth: Int) -> [InstantPageTableCell]? {
    guard context.budget.registerBlockDepth(depth), !context.budget.isExceeded else {
        return nil
    }

    let maxColumnIndex = nodes.reduce(-1) { partialResult, node in
        if case let .tableCell(column) = node.kind {
            return max(partialResult, column)
        } else {
            return partialResult
        }
    }
    let columnCount = max(alignments.count, maxColumnIndex + 1)
    guard columnCount > 0 else {
        return []
    }
    guard context.budget.registerTableColumns(columnCount) else {
        return nil
    }

    var result: [InstantPageTableCell] = []
    var nextColumn = 0
    
    for node in nodes {
        guard case let .tableCell(column) = node.kind else {
            continue
        }

        while nextColumn < column {
            result.append(markdownEmptyTableCell(header: header, alignment: markdownTableAlignment(at: nextColumn, from: alignments)))
            nextColumn += 1
        }

        guard let text = markdownRichText(from: node.attributedText, context: context) else {
            return nil
        }
        result.append(
            InstantPageTableCell(
                text: text,
                header: header,
                alignment: markdownTableAlignment(at: column, from: alignments),
                verticalAlignment: .top,
                colspan: 1,
                rowspan: 1
            )
        )
        nextColumn = max(nextColumn, column + 1)
    }
    
    while nextColumn < columnCount {
        result.append(markdownEmptyTableCell(header: header, alignment: markdownTableAlignment(at: nextColumn, from: alignments)))
        nextColumn += 1
    }
    
    guard context.budget.registerTableCells(result.count) else {
        return nil
    }
    return result
}

private func markdownEmptyTableCell(header: Bool, alignment: TableHorizontalAlignment) -> InstantPageTableCell {
    return InstantPageTableCell(
        text: .empty,
        header: header,
        alignment: alignment,
        verticalAlignment: .top,
        colspan: 1,
        rowspan: 1
    )
}

private func markdownTableAlignment(at index: Int, from alignments: [TableHorizontalAlignment]) -> TableHorizontalAlignment {
    guard index >= 0, index < alignments.count else {
        return .left
    }
    return alignments[index]
}

private func markdownRichText(from attributedString: NSAttributedString, context: MarkdownConversionContext) -> RichText? {
    return markdownInlineContent(from: attributedString, context: context)?.richText
}

private func markdownInlineContent(from attributedString: NSAttributedString, context: MarkdownConversionContext) -> MarkdownInlineContent? {
    guard attributedString.length > 0, #available(iOS 15.0, *) else {
        return MarkdownInlineContent(fragments: [])
    }

    var fragments: [MarkdownInlineFragment] = []
    var htmlStyles: [MarkdownHTMLInlineStyle] = []
    var consumeNextSoftBreak = false
    var didAbort = false

    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, stop in
        guard range.length > 0 else {
            return
        }
        if context.budget.isExceeded {
            didAbort = true
            stop.pointee = true
            return
        }
        
        let text = attributedString.attributedSubstring(from: range).string
        guard !text.isEmpty else {
            return
        }

        let inlineIntent: InlinePresentationIntent?
        if let inlineIntentValue = attributes[markdownInlinePresentationIntentAttribute] as? InlinePresentationIntent {
            inlineIntent = inlineIntentValue
        } else if let inlineIntentValue = attributes[markdownInlinePresentationIntentAttribute] as? NSNumber {
            inlineIntent = InlinePresentationIntent(rawValue: inlineIntentValue.uintValue)
        } else {
            inlineIntent = nil
        }

        if let inlineIntent, inlineIntent.contains(markdownInlineHTMLInlineIntent), let directive = markdownHTMLDirective(for: text) {
            switch directive {
            case let .open(style):
                htmlStyles.append(style)
                guard context.budget.registerInlineHTMLStyleDepth(htmlStyles.count) else {
                    didAbort = true
                    stop.pointee = true
                    return
                }
            case let .close(style):
                if let index = htmlStyles.lastIndex(of: style) {
                    htmlStyles.remove(at: index)
                }
            case .lineBreak:
                fragments.append(.richText(markdownApplyHTMLStyles(htmlStyles, to: .plain("\n"))))
                consumeNextSoftBreak = true
            }
            return
        }

        if consumeNextSoftBreak {
            if let inlineIntent, inlineIntent.contains(markdownSoftBreakInlineIntent), text == " " {
                consumeNextSoftBreak = false
                return
            }
            consumeNextSoftBreak = false
        }

        if let image = context.resolveImage(attributes: attributes) {
            fragments.append(.image(image))
            return
        }

        if let linkUrl = markdownLink(attributes: attributes, documentURL: context.documentURL),
           let fileId = parseCustomEmojiFileId(fromMarkdownURL: linkUrl) {
            // `text` is the parsed (already-unescaped) link display text = the alt.
            fragments.append(.richText(.textCustomEmoji(fileId: fileId, alt: text)))
            return
        }

        let segments = markdownInlineTextSegments(from: text, formulasByPlaceholder: context.formulasByPlaceholder)
        for segment in segments {
            let baseText: RichText
            let descriptor: MarkdownFormulaDescriptor?
            switch segment {
            case let .plain(plainText):
                baseText = .plain(plainText)
                descriptor = nil
            case let .formula(formulaDescriptor):
                baseText = .formula(latex: formulaDescriptor.latex)
                descriptor = formulaDescriptor
            }

            var fragment = markdownApplyingInlineIntent(inlineIntent, to: baseText)
            if let url = markdownLink(attributes: attributes, documentURL: context.documentURL) {
                fragment = .url(text: fragment, url: url, webpageId: nil)
            }
            fragment = markdownApplyHTMLStyles(htmlStyles, to: fragment)

            if let descriptor {
                fragments.append(.formula(descriptor, fragment))
            } else {
                fragments.append(.richText(fragment))
            }
        }
    }

    guard !didAbort, !context.budget.isExceeded else {
        return nil
    }
    return MarkdownInlineContent(fragments: fragments)
}

private func markdownInlineTextSegments(from text: String, formulasByPlaceholder: [String: MarkdownFormulaDescriptor]) -> [MarkdownInlineTextSegment] {
    guard !text.isEmpty else {
        return []
    }

    let nsText = text as NSString
    let matches = markdownFormulaPlaceholderRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    guard !matches.isEmpty else {
        return [.plain(text)]
    }

    var result: [MarkdownInlineTextSegment] = []
    var currentLocation = 0

    for match in matches {
        if match.range.location > currentLocation {
            result.append(.plain(nsText.substring(with: NSRange(location: currentLocation, length: match.range.location - currentLocation))))
        }

        let placeholder = nsText.substring(with: match.range)
        if let descriptor = formulasByPlaceholder[placeholder] {
            result.append(.formula(descriptor))
        } else {
            result.append(.plain(placeholder))
        }
        currentLocation = match.range.location + match.range.length
    }

    if currentLocation < nsText.length {
        result.append(.plain(nsText.substring(from: currentLocation)))
    }

    return result
}

@available(iOS 15.0, *)
private func markdownApplyingInlineIntent(_ inlineIntent: InlinePresentationIntent?, to text: RichText) -> RichText {
    guard let inlineIntent else {
        return text
    }

    var result = text
    if inlineIntent.contains(.stronglyEmphasized) {
        result = .bold(result)
    }
    if inlineIntent.contains(.emphasized) {
        result = .italic(result)
    }
    if inlineIntent.contains(.strikethrough) {
        result = .strikethrough(result)
    }
    if inlineIntent.contains(.code) {
        result = .fixed(result)
    }
    if inlineIntent.contains(markdownHardBreakInlineIntent) {
        result = .plain("\n")
    }
    return result
}

private enum MarkdownHTMLInlineStyle: Equatable {
    case underline
    case `subscript`
    case superscript
    case marked
}

private enum MarkdownHTMLDirective {
    case open(MarkdownHTMLInlineStyle)
    case close(MarkdownHTMLInlineStyle)
    case lineBreak
}

private func markdownHTMLDirective(for text: String) -> MarkdownHTMLDirective? {
    switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "<u>":
        return .open(.underline)
    case "</u>":
        return .close(.underline)
    case "<sub>":
        return .open(.subscript)
    case "</sub>":
        return .close(.subscript)
    case "<sup>":
        return .open(.superscript)
    case "</sup>":
        return .close(.superscript)
    case "<mark>":
        return .open(.marked)
    case "</mark>":
        return .close(.marked)
    case "<br>", "<br/>", "<br />":
        return .lineBreak
    default:
        return nil
    }
}

private func markdownApplyHTMLStyles(_ styles: [MarkdownHTMLInlineStyle], to text: RichText) -> RichText {
    var result = text
    for style in styles {
        switch style {
        case .underline:
            result = .underline(result)
        case .subscript:
            result = .subscript(result)
        case .superscript:
            result = .superscript(result)
        case .marked:
            result = .marked(result)
        }
    }
    return result
}

private func markdownAlternateDescription(attributes: [NSAttributedString.Key: Any]) -> String? {
    if let value = attributes[markdownAlternateDescriptionAttribute] as? String, !value.isEmpty {
        return value
    }
    return nil
}

private func markdownImageURL(attributes: [NSAttributedString.Key: Any]) -> String? {
    if let value = attributes[markdownImageURLAttribute] as? URL {
        return value.absoluteString
    }
    if let value = attributes[markdownImageURLAttribute] as? NSURL {
        return (value as URL).absoluteString
    }
    if let value = attributes[markdownImageURLAttribute] as? String, !value.isEmpty {
        return value
    }
    return nil
}

private func markdownResolveImageSource(_ value: String, limits: MarkdownSafetyLimits) -> MarkdownResolvedImageSource {
    if value.hasPrefix("//") {
        return .remote("https:\(value)")
    }
    
    if value.lowercased().hasPrefix("data:") {
        return markdownResolveDataImageSource(value, limits: limits)
    }
    
    guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
        return .unsupported
    }
    
    switch scheme {
    case "http", "https":
        return .remote(url.absoluteString)
    case "data":
        return markdownResolveDataImageSource(url.absoluteString, limits: limits)
    default:
        return .unsupported
    }
}

private func markdownResolveDataImageSource(_ value: String, limits: MarkdownSafetyLimits) -> MarkdownResolvedImageSource {
    guard value.lowercased().hasPrefix("data:"),
          let commaIndex = value.firstIndex(of: ",") else {
        return .unsupported
    }

    let header = String(value[value.index(value.startIndex, offsetBy: 5) ..< commaIndex])
    let payloadStart = value.index(after: commaIndex)
    let payload = String(value[payloadStart...])
    let isBase64 = header.lowercased().contains(";base64")

    let data: Data?
    if isBase64 {
        data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters])
    } else if let decodedPayload = payload.removingPercentEncoding {
        data = decodedPayload.data(using: .utf8)
    } else {
        data = nil
    }

    guard let data = data, data.count <= limits.maxDataImageBytes else {
        return .unsupported
    }

    guard let image = UIImage(data: data),
          let dimensions = markdownImagePixelDimensions(image) else {
        return .unsupported
    }

    let pixelCount = Int64(dimensions.width) * Int64(dimensions.height)
    guard pixelCount <= Int64(limits.maxDataImagePixelCount) else {
        return .unsupported
    }

    return .data(data, dimensions)
}

private func markdownImagePixelDimensions(_ image: UIImage) -> PixelDimensions? {
    if let cgImage = image.cgImage {
        return PixelDimensions(width: Int32(cgImage.width), height: Int32(cgImage.height))
    }
    
    let width = max(1, Int32(ceil(image.size.width * image.scale)))
    let height = max(1, Int32(ceil(image.size.height * image.scale)))
    return PixelDimensions(width: width, height: height)
}

private func markdownImageCaption(_ title: String?) -> InstantPageCaption {
    if let title, !title.isEmpty {
        return InstantPageCaption(text: .plain(title), credit: .empty)
    } else {
        return InstantPageCaption(text: .empty, credit: .empty)
    }
}

private func markdownInlineImageDimensions(attributes: [NSAttributedString.Key: Any]) -> PixelDimensions {
    guard let font = attributes[.font] as? UIFont else {
        return markdownDefaultInlineImageDimensions
    }

    let side = max(markdownDefaultInlineImageDimensions.width, Int32(ceil(font.lineHeight)))
    return PixelDimensions(width: side, height: side)
}

private func markdownLink(attributes: [NSAttributedString.Key: Any], documentURL: URL?) -> String? {
    if let value = attributes[markdownLinkAttribute] as? URL {
        return markdownNormalizedLink(value, documentURL: documentURL)
    }
    if let value = attributes[markdownLinkAttribute] as? NSURL {
        return markdownNormalizedLink(value as URL, documentURL: documentURL)
    }
    if let value = attributes[markdownLinkAttribute] as? String, !value.isEmpty {
        if value.hasPrefix("#") {
            return value
        }
        if let url = URL(string: value) {
            return markdownNormalizedLink(url, documentURL: documentURL)
        }
        return value
    }
    return nil
}

private func markdownNormalizedLink(_ url: URL, documentURL: URL?) -> String {
    if url.baseURL != nil {
        let relative = url.relativeString
        if relative.hasPrefix("#") {
            return relative
        }
    }
    if let documentURL, let fragment = url.fragment, markdownMatchesDocument(url, documentURL: documentURL) {
        return "#\(fragment)"
    }
    return url.absoluteString
}

private func markdownMatchesDocument(_ url: URL, documentURL: URL) -> Bool {
    let normalizedUrl = markdownURLWithoutFragment(url)
    let normalizedDocumentURL = markdownURLWithoutFragment(documentURL)
    
    if normalizedUrl.isFileURL && normalizedDocumentURL.isFileURL {
        return normalizedUrl.standardizedFileURL == normalizedDocumentURL.standardizedFileURL
    } else {
        return normalizedUrl == normalizedDocumentURL
    }
}

private func markdownURLWithoutFragment(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
        return url
    }
    components.fragment = nil
    return components.url ?? url
}

private func markdownCompact(_ fragments: [RichText]) -> RichText {
    var compacted: [RichText] = []
    for fragment in fragments {
        switch fragment {
        case .empty:
            continue
        case let .plain(text):
            guard !text.isEmpty else {
                continue
            }
            if let last = compacted.last, case let .plain(lastText) = last {
                compacted[compacted.count - 1] = .plain(lastText + text)
            } else {
                compacted.append(fragment)
            }
        case let .concat(items):
            let nested = markdownCompact(items)
            switch nested {
            case .empty:
                continue
            case let .plain(text):
                if let last = compacted.last, case let .plain(lastText) = last {
                    compacted[compacted.count - 1] = .plain(lastText + text)
                } else {
                    compacted.append(.plain(text))
                }
            default:
                compacted.append(nested)
            }
        default:
            compacted.append(fragment)
        }
    }
    if compacted.isEmpty {
        return .empty
    } else if compacted.count == 1 {
        return compacted[0]
    } else {
        return .concat(compacted)
    }
}

private func markdownDroppingPrefixLength(_ length: Int, from text: RichText) -> RichText {
    guard length > 0 else {
        return text
    }
    switch text {
    case .empty:
        return .empty
    case let .plain(string):
        let nsString = string as NSString
        if nsString.length <= length {
            return .empty
        } else {
            return .plain(nsString.substring(from: length))
        }
    case let .bold(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .bold(dropped)
    case let .italic(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .italic(dropped)
    case let .underline(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .underline(dropped)
    case let .strikethrough(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .strikethrough(dropped)
    case let .fixed(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .fixed(dropped)
    case let .url(inner, url, webpageId):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .url(text: dropped, url: url, webpageId: webpageId)
    case let .email(inner, email):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .email(text: dropped, email: email)
    case let .concat(items):
        var remainingLength = length
        var result: [RichText] = []
        result.reserveCapacity(items.count)
        for item in items {
            if remainingLength > 0 {
                let itemLength = (item.plainText as NSString).length
                if itemLength <= remainingLength {
                    remainingLength -= itemLength
                    continue
                }
                result.append(markdownDroppingPrefixLength(remainingLength, from: item))
                remainingLength = 0
            } else {
                result.append(item)
            }
        }
        return markdownCompact(result)
    case let .subscript(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .subscript(dropped)
    case let .superscript(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .superscript(dropped)
    case let .marked(inner):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .marked(dropped)
    case let .phone(inner, phone):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .phone(text: dropped, phone: phone)
    case .image:
        return text
    case let .formula(latex):
        let nsLatex = latex as NSString
        if nsLatex.length <= length {
            return .empty
        } else {
            return .plain(nsLatex.substring(from: length))
        }
    case let .anchor(inner, name):
        let dropped = markdownDroppingPrefixLength(length, from: inner)
        return dropped == .empty ? .empty : .anchor(text: dropped, name: name)
    case .textCustomEmoji:
        return text
    case .textAutoEmail, .textAutoPhone, .textAutoUrl, .textBankCard, .textTonAddress, .textBotCommand, .textCashtag, .textHashtag, .textMention, .textMentionName, .textSpoiler, .textDate:
        return text
    case .textButton:
        // An atom, like .image above: a prefix drop must not split a button's label.
        return text
    }
}

private func markdownHasDisplayableContent(_ richText: RichText) -> Bool {
    switch richText {
    case .empty:
        return false
    case let .plain(text):
        return !text.isEmpty
    case let .bold(text),
         let .italic(text),
         let .underline(text),
         let .strikethrough(text),
         let .fixed(text),
         let .subscript(text),
         let .superscript(text),
         let .marked(text),
         let .anchor(text, _):
        return markdownHasDisplayableContent(text)
    case let .url(text, _, _),
         let .email(text, _),
         let .phone(text, _):
        return markdownHasDisplayableContent(text)
    case let .concat(items):
        return items.contains(where: markdownHasDisplayableContent)
    case .image:
        return true
    case let .formula(latex):
        return !latex.isEmpty
    case .textCustomEmoji:
        return true
    case .textAutoEmail, .textAutoPhone, .textAutoUrl, .textBankCard, .textTonAddress, .textBotCommand, .textCashtag, .textHashtag, .textMention, .textMentionName, .textSpoiler, .textDate:
        return true
    case .textButton:
        // A button is always displayable content, even if its label is empty — the pill shows.
        return true
    }
}

private func markdownIsWhitespaceOnly(_ richText: RichText) -> Bool {
    switch richText {
    case .empty:
        return true
    case let .plain(text):
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case let .bold(text),
         let .italic(text),
         let .underline(text),
         let .strikethrough(text),
         let .fixed(text),
         let .subscript(text),
         let .superscript(text),
         let .marked(text),
         let .anchor(text, _):
        return markdownIsWhitespaceOnly(text)
    case let .url(text, _, _),
         let .email(text, _),
         let .phone(text, _):
        return markdownIsWhitespaceOnly(text)
    case let .concat(items):
        return items.allSatisfy(markdownIsWhitespaceOnly)
    case .image:
        return false
    case let .formula(latex):
        return latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .textCustomEmoji:
        return false
    case .textAutoEmail, .textAutoPhone, .textAutoUrl, .textBankCard, .textTonAddress, .textBotCommand, .textCashtag, .textHashtag, .textMention, .textMentionName, .textSpoiler, .textDate:
        return false
    case .textButton:
        // Never whitespace-only: a button is a visible element regardless of its label.
        return false
    }
}

private func markdownPlainText(from block: InstantPageBlock, depth: Int = 0) -> String {
    guard depth <= markdownSafetyLimits.maxPresentationIntentDepth else {
        return ""
    }

    switch block {
    case let .title(text):
        return text.plainText
    case let .subtitle(text):
        return text.plainText
    case let .authorDate(author, _):
        return author.plainText
    case let .header(text):
        return text.plainText
    case let .subheader(text):
        return text.plainText
    case let .heading(text, _):
        return text.plainText
    case let .formula(latex):
        return latex
    case let .paragraph(text):
        return text.plainText
    case let .preformatted(text, _):
        return text.plainText
    case let .footer(text):
        return text.plainText
    case let .blockQuote(blocks, caption, _):
        let blocksText = blocks.map { markdownPlainText(from: $0, depth: depth + 1) }.joined(separator: "\n")
        return blocksText.isEmpty ? caption.plainText : blocksText
    case let .pullQuote(text, caption):
        return text.plainText.isEmpty ? caption.plainText : text.plainText
    case let .kicker(text):
        return text.plainText
    case let .table(title, _, _, _, _):
        return title.plainText
    case let .details(title, _, _):
        return title.plainText
    case let .relatedArticles(title, _):
        return title.plainText
    default:
        return ""
    }
}

private func markdownTitle(from blocks: [InstantPageBlock], file: FileMediaReference, fileURL: URL) -> String {
    for block in blocks {
        if case let .title(text) = block, !text.plainText.isEmpty {
            return text.plainText
        }
    }
    if let fileName = file.media.fileName, !fileName.isEmpty {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        if !baseName.isEmpty {
            return baseName
        }
        return fileName
    }
    let baseName = fileURL.deletingPathExtension().lastPathComponent
    if !baseName.isEmpty {
        return baseName
    }
    return fileURL.lastPathComponent
}

private func markdownNormalizedCodeBlockLanguage(_ language: String?) -> String? {
    guard let language else {
        return nil
    }
    let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
}

private func markdownFirstParagraphText(from blocks: [InstantPageBlock], depth: Int = 0) -> String? {
    guard depth <= markdownSafetyLimits.maxPresentationIntentDepth else {
        return nil
    }

    for block in blocks {
        switch block {
        case let .formula(latex):
            if !latex.isEmpty {
                return latex
            }
        case let .paragraph(text):
            if !text.plainText.isEmpty {
                return text.plainText
            }
        case let .list(items, _):
            for item in items {
                switch item {
                case let .text(text, _, _):
                    if !text.plainText.isEmpty {
                        return text.plainText
                    }
                case let .blocks(blocks, _, _):
                    if let text = markdownFirstParagraphText(from: blocks, depth: depth + 1) {
                        return text
                    }
                default:
                    break
                }
            }
        case let .details(_, blocks, _):
            if let text = markdownFirstParagraphText(from: blocks, depth: depth + 1) {
                return text
            }
        default:
            break
        }
    }
    return nil
}

private func markdownBlocksWithGeneratedAnchors(_ blocks: [InstantPageBlock]) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    var slugCounts: [String: Int] = [:]
    
    for block in blocks {
        if let headingText = markdownHeadingText(from: block), !headingText.isEmpty {
            let baseSlug = markdownAnchorSlug(from: headingText)
            if !baseSlug.isEmpty {
                let count = slugCounts[baseSlug] ?? 0
                slugCounts[baseSlug] = count + 1
                
                let slug: String
                if count == 0 {
                    slug = baseSlug
                } else {
                    slug = "\(baseSlug)-\(count)"
                }
                result.append(.anchor(slug))
            }
        }
        result.append(block)
    }
    
    return result
}

private func markdownHeadingText(from block: InstantPageBlock) -> String? {
    switch block {
    case let .title(text):
        return text.plainText
    case let .header(text):
        return text.plainText
    case let .subheader(text):
        return text.plainText
    case let .heading(text, _):
        return text.plainText
    default:
        return nil
    }
}

private func markdownAnchorSlug(from text: String) -> String {
    let normalized = text
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        .lowercased()
    
    let dashScalar = "-".unicodeScalars.first!
    let separatorSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-_"))
    var scalars: [UnicodeScalar] = []
    var previousWasDash = false
    
    for scalar in normalized.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            scalars.append(scalar)
            previousWasDash = false
        } else if separatorSet.contains(scalar) {
            if !scalars.isEmpty && !previousWasDash {
                scalars.append(dashScalar)
                previousWasDash = true
            }
        }
    }
    
    if scalars.last == dashScalar {
        scalars.removeLast()
    }
    
    return String(String.UnicodeScalarView(scalars))
}

private func markdownTrimTrailingCodeBlockNewline(_ attributedString: NSAttributedString) -> NSAttributedString {
    guard attributedString.length > 0 else {
        return attributedString
    }
    let mutable = NSMutableAttributedString(attributedString: attributedString)
    let string = mutable.string
    if string.hasSuffix("\r\n"), mutable.length >= 2 {
        mutable.deleteCharacters(in: NSRange(location: mutable.length - 2, length: 2))
    } else if string.hasSuffix("\n") {
        mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
    }
    return mutable
}

private enum MarkdownIntentKind {
    case table([TableHorizontalAlignment])
    case tableHeaderRow
    case tableRow
    case tableCell(Int)
    case paragraph
    case header(Int)
    case codeBlock(String?)
    case thematicBreak
    case blockQuote
    case unorderedList
    case orderedList
    case listItem(Int)
    case unknown
    
    @available(iOS 15.0, *)
    init(component: PresentationIntent.IntentType) {
        switch component.kind {
        case let .table(columns):
            self = .table(columns.map(markdownTableColumnAlignment))
        case .tableHeaderRow:
            self = .tableHeaderRow
        case .tableRow(_):
            self = .tableRow
        case let .tableCell(column):
            self = .tableCell(column)
        case .paragraph:
            self = .paragraph
        case let .header(level):
            self = .header(level)
        case let .codeBlock(languageHint):
            self = .codeBlock(languageHint)
        case .thematicBreak:
            self = .thematicBreak
        case .blockQuote:
            self = .blockQuote
        case .unorderedList:
            self = .unorderedList
        case .orderedList:
            self = .orderedList
        case let .listItem(ordinal):
            self = .listItem(ordinal)
        default:
            self = .unknown
        }
    }
}

@available(iOS 15.0, *)
private func markdownTableColumnAlignment(_ column: PresentationIntent.TableColumn) -> TableHorizontalAlignment {
    switch column.alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    @unknown default:
        return .left
    }
}

private final class MarkdownIntentNode {
    let identity: Int
    let kind: MarkdownIntentKind
    
    private(set) var children: [MarkdownIntentNode] = []
    private var childIdentities: Set<Int> = []
    private(set) var attributedText = NSMutableAttributedString(string: "")
    
    @available(iOS 15.0, *)
    init(component: PresentationIntent.IntentType) {
        self.identity = component.identity
        self.kind = MarkdownIntentKind(component: component)
    }
    
    func append(child: MarkdownIntentNode) {
        if self.childIdentities.insert(child.identity).inserted {
            self.children.append(child)
        }
    }
    
    func append(text: NSAttributedString) {
        self.attributedText.append(text)
    }
}
