import Foundation
import TelegramCore
import TextFormat

/// Reconstructs a markdown source string from an `InstantPage`.
///
/// This is the inverse of the markdown→`InstantPage` conversion used when
/// sending rich messages. It is best-effort and never fails: media blocks
/// (images/videos/audio/embeds/maps) are skipped, and any block or inline node
/// without a CommonMark representation falls back to its plain text.
///
/// Inline formatting is emitted as CommonMark (`**bold**`, `*italic*`,
/// `` `code` ``, `~~strike~~`, `[text](url)`) because the send-time classifier
/// re-parses the text through the rich (Apple CommonMark) path, not the entity
/// regex.
public func markdownStringFromInstantPage(_ instantPage: InstantPage) -> String {
    return markdownString(from: instantPage.blocks)
}

private func markdownString(from blocks: [InstantPageBlock]) -> String {
    var pieces: [String] = []
    for block in blocks {
        if let piece = markdownString(from: block) {
            pieces.append(piece)
        }
    }
    return pieces.joined(separator: "\n\n")
}

private func markdownString(from block: InstantPageBlock) -> String? {
    switch block {
    case let .heading(text, level):
        let hashes = String(repeating: "#", count: max(1, min(6, Int(level))))
        return "\(hashes) \(markdownInline(from: text))"
    case let .title(text):
        return "# \(markdownInline(from: text))"
    case let .paragraph(text):
        let rendered = markdownInline(from: text)
        return rendered.isEmpty ? nil : escapeLeadingBlockMarker(rendered)
    case let .preformatted(text, language):
        let language = language ?? ""
        // Code-fence body is raw text: the fences supply the code formatting, so do NOT run it
        // through markdownInline (which re-wraps `.fixed` content in backticks and escapes markdown
        // special chars). Use plainText to emit the literal source.
        return "```\(language)\n\(text.plainText)\n```"
    case let .blockQuote(blocks, _, _):
        return markdownBlockQuoteBlocks(blocks)
    case let .pullQuote(text, _):
        return markdownBlockQuote(text)
    case let .list(items, ordered):
        return markdownList(items: items, ordered: ordered, indent: 0)
    case let .table(_, rows, _, _, _):
        return markdownTable(rows: rows)
    case .divider:
        return "---"
    case let .formula(latex):
        return "$\(latex)$"
    case .anchor:
        // Chat send already strips generated heading anchors; drop them here too.
        return nil
    case let .subtitle(text), let .header(text), let .subheader(text), let .footer(text), let .kicker(text):
        let rendered = markdownInline(from: text)
        return rendered.isEmpty ? nil : escapeLeadingBlockMarker(rendered)
    default:
        // Media and other structural blocks are skipped (out of scope).
        return nil
    }
}

private func markdownBlockQuote(_ text: RichText) -> String {
    let body = markdownInline(from: text)
    let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
    return lines.map { "> \($0)" }.joined(separator: "\n")
}

private func markdownBlockQuoteBlocks(_ blocks: [InstantPageBlock]) -> String {
    var lines: [String] = []
    for block in blocks {
        guard let body = markdownString(from: block) else {
            continue
        }
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            // Stack nested-quote markers without internal spaces (`>>` not `> >`):
            // a line already starting with `>` (a nested quote) gets a bare `>`.
            let text = String(line)
            lines.append(text.hasPrefix(">") ? ">\(text)" : "> \(text)")
        }
    }
    return lines.joined(separator: "\n")
}

private func markdownInline(from richText: RichText) -> String {
    switch richText {
    case .empty:
        return ""
    case let .plain(string):
        return escapeMarkdown(string)
    case let .bold(text):
        return "**\(markdownInline(from: text))**"
    case let .italic(text):
        return "*\(markdownInline(from: text))*"
    case let .fixed(text):
        return "`\(markdownInline(from: text))`"
    case let .strikethrough(text):
        return "~~\(markdownInline(from: text))~~"
    case let .url(text, url, _):
        return "[\(markdownInline(from: text))](\(url))"
    case let .email(text, email):
        return "[\(markdownInline(from: text))](mailto:\(email))"
    case let .phone(text, phone):
        return "[\(markdownInline(from: text))](tel:\(phone))"
    case let .textTonAddress(text):
        return markdownInline(from: text)
    case let .concat(parts):
        return parts.map { markdownInline(from: $0) }.joined()
    case let .anchor(text, _):
        return markdownInline(from: text)
    case let .formula(latex):
        return "$\(latex)$"
    // No CommonMark equivalent; emit inner text. These cannot arise from a
    // markdown-composed message (Apple's markdown parser never produces them),
    // so this is purely defensive.
    case let .underline(text):
        return markdownInline(from: text)
    case let .marked(text):
        return markdownInline(from: text)
    case let .superscript(text):
        return markdownInline(from: text)
    case let .`subscript`(text):
        return markdownInline(from: text)
    case let .textCustomEmoji(fileId, alt):
        return "[\(escapeCustomEmojiMarkdownAlt(alt))](\(customEmojiMarkdownURL(fileId: fileId)))"
    case let .textButton(button):
        // KNOWN LOSSY: markdown has no spelling for a button, so an edit round-trip
        // (InstantPage -> markdown -> InstantPage) keeps the label and drops the action and style.
        // Recorded as a deferred hazard in docs/instantpage-richtext.md rather than fixed here; the
        // fix would be to gate the edit affordance on a positive InstantPage.containsButtons check.
        // Stated explicitly instead of falling through to `default` so the loss is visible at the
        // site.
        return markdownInline(from: button.text)
    default:
        // .image and the entity cases (.textMention, .textHashtag, …):
        // fall back to plain text.
        return escapeMarkdown(richText.plainText)
    }
}

/// Backslash-escapes inline markdown-significant characters so literal text
/// does not re-parse as formatting. Pragmatic set, not full CommonMark.
private func escapeMarkdown(_ string: String) -> String {
    var result = ""
    result.reserveCapacity(string.count)
    for character in string {
        switch character {
        case "\\", "*", "_", "`", "[", "]", "~", "|":
            result.append("\\")
            result.append(character)
        default:
            result.append(character)
        }
    }
    return result
}

/// Escapes a line-leading character that would otherwise be read as a block
/// marker (ATX heading, blockquote, or list item) when the text starts a line.
private func escapeLeadingBlockMarker(_ string: String) -> String {
    guard let first = string.first else {
        return string
    }
    if first == "#" || first == ">" || first == "-" || first == "+" {
        return "\\" + string
    }
    // Ordered-list marker: one or more digits followed by '.' or ')'.
    if first.isNumber {
        var index = string.startIndex
        while index < string.endIndex, string[index].isNumber {
            index = string.index(after: index)
        }
        if index < string.endIndex, string[index] == "." || string[index] == ")" {
            let prefix = string[string.startIndex ..< index]
            let delimiter = string[index]
            let rest = string[string.index(after: index)...]
            return "\(prefix)\\\(delimiter)\(rest)"
        }
    }
    return string
}

/// Collapses newlines for a single-line GFM table cell. The `|` character is
/// already escaped by `escapeMarkdown` for `.plain` runs.
private func escapeTableCell(_ string: String) -> String {
    return string.replacingOccurrences(of: "\n", with: " ")
}

private func markdownList(items: [InstantPageListItem], ordered: Bool, indent: Int) -> String {
    let indentString = String(repeating: " ", count: indent * 2)
    var lines: [String] = []
    var index = 1
    for item in items {
        // Ordered markers are regenerated from the running index (CommonMark renumbers
        // anyway); the unordered marker is fixed. A task-list `checked` state is emitted
        // as a GitHub task marker so re-classification on save re-parses it as a checkbox.
        let listMarker = ordered ? "\(index). " : "- "
        let taskMarker: String
        switch item.checked {
        case .some(false):
            taskMarker = "[ ] "
        case .some(true):
            taskMarker = "[x] "
        case .none:
            taskMarker = ""
        }
        let marker = "\(listMarker)\(taskMarker)"
        switch item {
        case let .text(text, _, _):
            lines.append("\(indentString)\(marker)\(markdownInline(from: text))")
        case let .blocks(blocks, _, _):
            var remainder = blocks
            var markerLineText = ""
            if case let .paragraph(text)? = remainder.first {
                markerLineText = markdownInline(from: text)
                remainder = Array(remainder.dropFirst())
            }
            lines.append("\(indentString)\(marker)\(markerLineText)")
            let childIndentString = String(repeating: " ", count: (indent + 1) * 2)
            for block in remainder {
                if case let .list(nestedItems, nestedOrdered) = block {
                    lines.append(markdownList(items: nestedItems, ordered: nestedOrdered, indent: indent + 1))
                } else if let rendered = markdownString(from: block) {
                    for line in rendered.split(separator: "\n", omittingEmptySubsequences: false) {
                        lines.append("\(childIndentString)\(line)")
                    }
                }
            }
        case .unknown:
            break
        }
        index += 1
    }
    return lines.joined(separator: "\n")
}

private func markdownTable(rows: [InstantPageTableRow]) -> String? {
    guard !rows.isEmpty else {
        return nil
    }
    let columnCount = rows.map { $0.cells.count }.max() ?? 0
    guard columnCount > 0 else {
        return nil
    }

    func renderRow(_ row: InstantPageTableRow) -> String {
        var cellStrings: [String] = []
        for columnIndex in 0 ..< columnCount {
            if columnIndex < row.cells.count, let text = row.cells[columnIndex].text {
                cellStrings.append(escapeTableCell(markdownInline(from: text)))
            } else {
                cellStrings.append("")
            }
        }
        return "| " + cellStrings.joined(separator: " | ") + " |"
    }

    var lines: [String] = []
    lines.append(renderRow(rows[0]))

    var separators: [String] = []
    for columnIndex in 0 ..< columnCount {
        let alignment: TableHorizontalAlignment
        if columnIndex < rows[0].cells.count {
            alignment = rows[0].cells[columnIndex].alignment
        } else {
            alignment = .left
        }
        switch alignment {
        case .left:
            separators.append("---")
        case .center:
            separators.append(":---:")
        case .right:
            separators.append("---:")
        }
    }
    lines.append("| " + separators.joined(separator: " | ") + " |")

    for row in rows.dropFirst() {
        lines.append(renderRow(row))
    }
    return lines.joined(separator: "\n")
}
