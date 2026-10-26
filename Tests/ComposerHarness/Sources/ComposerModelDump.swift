import Foundation
import TelegramCore
import HarnessAppContext

/// A deterministic text rendering of the composer's live state.
///
/// **It asks; it never recomputes.** Every value here comes from the panel or its node. A readout
/// that derived anything itself would start agreeing with itself instead of with the product,
/// which would make the whole inspection surface worthless.
///
/// **This is a test contract.** Tier-2 cases read it out of process as an accessibility value and
/// match on it. Changing the shape is a breaking change: bump `formatVersion` and fix the callers.
public enum ComposerModelDump {
    public static let formatVersion = 1

    public static func text(for host: HarnessPanelHost) -> String {
        let state = host.panel.inputTextState
        let content = state.content
        let backend = host.liveBackend?.rawValue ?? "none"

        var lines: [String] = []
        lines.append("dump v\(self.formatVersion) backend=\(backend) "
            + "hasText=\(!content.plainText.isEmpty)")
        // The height the last REAL layout pass produced; never re-measured here.
        lines.append("height=\(String(format: "%.1f", host.lastMeasuredHeight))")
        lines.append("selection=\(state.selectionRange.lowerBound)"
            + "..<\(state.selectionRange.upperBound)")
        lines.append("blocks=\(content.blocks.count)")
        for (index, block) in content.blocks.enumerated() {
            lines.append(contentsOf: self.describe(block: block, index: index, indent: 0))
        }
        return lines.joined(separator: "\n")
    }

    /// **One arm per case, and deliberately no `default`.** Exhaustiveness is what reports a new
    /// block kind; a `default` would absorb one silently and the dump would go quietly wrong,
    /// which is the exact class of failure this readout exists to prevent.
    private static func describe(block: ChatInputBlock, index: Int, indent: Int) -> [String] {
        let pad = String(repeating: "  ", count: indent)
        let head = "\(pad)block[\(index)] "
        switch block {
        case let .paragraph(paragraph):
            let list = paragraph.list.map { " list=\($0)" } ?? ""
            return [head + "paragraph style=\(paragraph.style)\(list)"]
                + self.describe(runs: paragraph.runs, indent: indent + 1)
        case let .code(code):
            return [head + "code language=\(code.language ?? "-")"]
                + self.describe(runs: code.runs, indent: indent + 1)
        case let .media(media):
            // A `.media` block is a GROUP: ChatInputMedia holds `items`, and it is the individual
            // ChatInputMediaItem that carries kind/size/spoiler.
            let items = media.items.map { item in
                return "\(item.kind)/\(item.naturalSize)"
                    + (item.isSpoiler ? "/spoiler" : "")
            }
            return [head + "media items=[\(items.joined(separator: " "))]"]
        case let .table(table):
            return [head + "table rows=\(table.rows.count)"]
        case let .pullQuote(quote):
            return [head + "pullQuote author=\(quote.author.count)"]
                + self.describe(runs: quote.runs, indent: indent + 1)
        case let .blockQuote(quote):
            return [head + "blockQuote collapsed=\(quote.collapsed) author=\(quote.author.count)"]
                + self.describe(content: quote.content, indent: indent + 1)
        case let .details(details):
            return [head + "details expanded=\(details.expanded) title=\(details.title.count)"]
                + self.describe(content: details.content, indent: indent + 1)
        case .buttonRow:
            return [head + "buttonRow"]
        }
    }

    private static func describe(content: ChatInputContent, indent: Int) -> [String] {
        return content.blocks.enumerated().flatMap { index, block in
            return self.describe(block: block, index: index, indent: indent)
        }
    }

    private static func describe(runs: [ChatInputRun], indent: Int) -> [String] {
        let pad = String(repeating: "  ", count: indent)
        var offset = 0
        return runs.map { run in
            let end = offset + run.text.utf16.count
            defer { offset = end }
            return "\(pad)run \(offset)..<\(end) "
                + "[\(self.describe(attributes: run.attributes))] \(run.text.debugDescription)"
        }
    }

    /// Only the attributes that are ON, in a fixed order, so the line is stable and short.
    private static func describe(attributes: ChatInputInlineAttributes) -> String {
        var flags: [String] = []
        if attributes.bold { flags.append("b") }
        if attributes.italic { flags.append("i") }
        if attributes.monospace { flags.append("m") }
        if attributes.strikethrough { flags.append("s") }
        if attributes.underline { flags.append("u") }
        if attributes.spoiler { flags.append("sp") }
        if let formula = attributes.formula { flags.append("formula=\(formula)") }
        if let entity = attributes.entity { flags.append("entity=\(entity)") }
        return flags.joined(separator: ",")
    }
}
