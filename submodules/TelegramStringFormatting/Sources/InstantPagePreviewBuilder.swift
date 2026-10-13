import Foundation
import UIKit
import Postbox
import TelegramCore
import TextFormat

struct InstantPagePreviewEnvironment {
    let label: (InstantPagePreviewLabel) -> String
    let formatDate: ((Int32, MessageTextEntityType.DateTimeFormat) -> String)?
    let media: [MediaId: Media]
}

enum InstantPagePreviewLabel {
    case photo, video, voice, music, file, location
    case formula, table, unsupported, embeddedContent, channel
    case photos(Int32), videos(Int32)
}

let instantPagePreviewCustomEmoji = NSAttributedString.Key("TelegramInstantPagePreviewCustomEmoji")
let instantPagePreviewIcon = NSAttributedString.Key("TelegramInstantPagePreviewIcon")
let instantPagePreviewIconFallback = NSAttributedString.Key("TelegramInstantPagePreviewIconFallback")
private let instantPagePreviewItalic = NSAttributedString.Key("TelegramInstantPagePreviewItalic")

// An icon/emoji is atomic even when its backing string contains several characters.
func clipInstantPagePreview(_ text: NSAttributedString, limit: Int = 200, truncated: Bool = false) -> NSAttributedString {
    guard truncated || text.string.count > limit else { return text }
    let index = text.string.index(text.string.startIndex, offsetBy: min(limit - 1, text.string.count))
    var end = NSRange(text.string.startIndex ..< index, in: text.string).length
    if end > 0 && end < text.length {
        var range = NSRange()
        let emoji = text.attribute(instantPagePreviewCustomEmoji, at: end, effectiveRange: &range) ?? text.attribute(ChatTextInputAttributes.customEmoji, at: end, effectiveRange: &range)
        if emoji != nil, range.location < end {
            end = range.location
        }
    }
    let result = NSMutableAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: 0, length: end)))
    while result.string.last?.isWhitespace == true { result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1)) }
    result.append(NSAttributedString(string: "…"))
    return result
}

private func trimPreview(_ text: NSAttributedString) -> NSAttributedString {
    let string = text.string
    let start = string.firstIndex(where: { !$0.isWhitespace }) ?? string.endIndex
    let end = string.lastIndex(where: { !$0.isWhitespace }).map { string.index(after: $0) } ?? start
    return text.attributedSubstring(from: NSRange(start ..< end, in: string))
}

private final class InstantPagePreviewBuilder {
    let environment: InstantPagePreviewEnvironment
    var nodesLeft = 4096
    var textUnitsLeft = 16384
    var exhausted = false
    private var thinking: [(RichText, Int)] = []

    init(environment: InstantPagePreviewEnvironment) {
        self.environment = environment
    }

    private func enter(_ depth: Int) -> Bool {
        guard !self.exhausted else { return false }
        guard depth <= 64, self.nodesLeft > 0 else { self.exhausted = true; return false }
        self.nodesLeft -= 1
        return true
    }

    // Bound the input BEFORE asking Swift to find grapheme boundaries. If cut in
    // the middle of a grapheme, conservatively omit the last cluster of the prefix.
    private func text(_ value: String) -> NSAttributedString {
        let units = Array(value.utf16.prefix(self.textUnitsLeft + 1))
        let cut = units.count > self.textUnitsLeft
        let prefix = String(decoding: units.prefix(self.textUnitsLeft), as: UTF16.self)
        self.textUnitsLeft -= min(units.count, self.textUnitsLeft)
        if cut { self.exhausted = true }
        let input = cut && !prefix.isEmpty ? String(prefix.dropLast()) : prefix
        var output = ""
        var wasSpace = false
        var count = 0
        for character in input {
            if character.isWhitespace {
                if !wasSpace { output.append(" "); count += 1 }
                wasSpace = true
            } else {
                output.append(character)
                count += 1
                wasSpace = false
            }
            if count > 200 && !character.isWhitespace { break }
        }
        return NSAttributedString(string: output)
    }

    private func label(_ label: InstantPagePreviewLabel) -> NSAttributedString {
        return self.text(self.environment.label(label))
    }

    private func join(_ values: [NSAttributedString]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for value in values {
            let value = trimPreview(value)
            guard value.length != 0 else { continue }
            if result.length != 0 { result.append(NSAttributedString(string: " ")) }
            result.append(value)
            if result.string.count > 200 { break }
        }
        return result
    }

    private func attribute(_ key: NSAttributedString.Key, _ value: Any, _ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        result.addAttribute(key, value: value, range: NSRange(location: 0, length: result.length))
        return result
    }

    private func icon(_ label: InstantPagePreviewLabel, value: Int32) -> NSAttributedString {
        return NSAttributedString(string: "\u{fffc}", attributes: [
            instantPagePreviewIcon: NSNumber(value: value),
            instantPagePreviewIconFallback: self.environment.label(label)
        ])
    }

    func rich(_ value: RichText, depth: Int) -> NSAttributedString {
        guard self.enter(depth) else { return NSAttributedString() }
        switch value {
        case .empty: return NSAttributedString()
        case let .plain(value): return self.text(value)
        case let .italic(value): return self.attribute(instantPagePreviewItalic, true, self.rich(value, depth: depth + 1))
        case let .underline(value): return self.attribute(.underlineStyle, NSUnderlineStyle.single.rawValue, self.rich(value, depth: depth + 1))
        case let .strikethrough(value): return self.attribute(.strikethroughStyle, NSUnderlineStyle.single.rawValue, self.rich(value, depth: depth + 1))
        case let .textSpoiler(value): return self.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), true, self.rich(value, depth: depth + 1))
        case let .textDate(value, date, format):
            let text: NSAttributedString
            if let format, let formatDate = self.environment.formatDate {
                text = self.text(formatDate(date, format))
            } else {
                text = self.rich(value, depth: depth + 1)
            }
            return self.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Date), date, text)
        case let .textCustomEmoji(fileId, alt):
            let file = self.environment.media[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile
            let text = self.text(alt.isEmpty ? (file == nil ? "�" : "\u{fffc}") : alt)
            let emoji = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: file)
            let result = self.attribute(instantPagePreviewCustomEmoji, emoji, text)
            // Entity text nodes replace the backing text by an attachment. Without
            // a known file that would hide alt text even when resolution fails.
            return file == nil ? result : self.attribute(ChatTextInputAttributes.customEmoji, emoji, result)
        case .formula: return self.icon(.formula, value: 0)
        case .image: return self.label(.photo)
        case let .textButton(button): return self.rich(button.text, depth: depth + 1)
        case let .concat(values):
            let result = NSMutableAttributedString()
            for value in values {
                if self.exhausted || trimPreview(result).string.count > 200 { break }
                let next = self.rich(value, depth: depth + 1)
                // Each leaf normalizes whitespace, but adjacent leaves can meet at a space.
                if result.string.last == " ", next.string.first == " " {
                    result.append(next.attributedSubstring(from: NSRange(location: 1, length: next.length - 1)))
                } else {
                    result.append(next)
                }
            }
            return result
        case let .bold(value), let .fixed(value), let .subscript(value), let .superscript(value), let .marked(value), let .url(value, _, _), let .email(value, _), let .phone(value, _), let .anchor(value, _), let .textAutoEmail(value), let .textAutoPhone(value), let .textAutoUrl(value), let .textBankCard(value), let .textTonAddress(value), let .textBotCommand(value), let .textCashtag(value), let .textHashtag(value), let .textMention(value), let .textMentionName(value, _):
            return self.rich(value, depth: depth + 1)
        }
    }

    private struct Fragment {
        let text: NSAttributedString
        var photos: Int32 = 0
        var videos: Int32 = 0
        var mediaOnly = false
    }

    private func caption(_ value: InstantPageCaption, depth: Int) -> NSAttributedString {
        return self.join([self.rich(value.text, depth: depth + 1), self.rich(value.credit, depth: depth + 1)])
    }

    func blocks(_ values: [InstantPageBlock], depth: Int) -> NSAttributedString {
        var result: [NSAttributedString] = []
        var length = 0
        for value in values {
            guard !self.exhausted, length <= 200 else { break }
            if case let .thinking(text) = value {
                guard self.enter(depth) else { break }
                self.thinking.append((text, depth + 1))
                continue
            }
            let text = trimPreview(self.block(value, depth: depth).text)
            if text.length != 0 {
                result.append(text)
                length += text.string.count + (result.count > 1 ? 1 : 0)
            }
        }
        return self.join(result)
    }

    func thinkingFallback() -> NSAttributedString {
        var values: [NSAttributedString] = []
        var length = 0
        for (text, depth) in self.thinking {
            guard !self.exhausted, length <= 200 else { break }
            let value = self.rich(text, depth: depth)
            values.append(value)
            length += value.string.count + 1
        }
        return self.join(values)
    }

    private func block(_ value: InstantPageBlock, depth: Int) -> Fragment {
        guard self.enter(depth) else { return Fragment(text: NSAttributedString()) }
        let next = depth + 1
        let text: NSAttributedString
        switch value {
        case let .title(value), let .subtitle(value), let .header(value), let .subheader(value), let .paragraph(value), let .footer(value), let .kicker(value), let .heading(value, _), let .preformatted(value, _), let .authorDate(value, _):
            text = self.rich(value, depth: next)
        case let .thinking(value):
            self.thinking.append((value, next))
            text = NSAttributedString()
        case .unsupported: text = self.label(.unsupported)
        case .divider, .anchor: text = NSAttributedString()
        case .formula: text = self.icon(.formula, value: 0)
        case let .table(title, _, _, _, _): text = self.join([self.icon(.table, value: 1), self.rich(title, depth: next)])
        case let .cover(value): return self.block(value, depth: next)
        case let .blockQuote(values, caption, _): text = self.join([self.blocks(values, depth: next), self.rich(caption, depth: next)])
        case let .pullQuote(value, caption): text = self.join([self.rich(value, depth: next), self.rich(caption, depth: next)])
        case let .details(title, values, _): text = self.join([self.rich(title, depth: next), self.blocks(values, depth: next)])
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _):
            let isPhoto: Bool
            if case .image = value { isPhoto = true } else { isPhoto = false }
            let captionText = self.caption(caption, depth: next)
            return Fragment(text: self.join([self.label(isPhoto ? .photo : .video), captionText]), photos: isPhoto ? 1 : 0, videos: isPhoto ? 0 : 1, mediaOnly: captionText.length == 0)
        case let .audio(id, caption):
            text = self.join([self.label((self.environment.media[id] as? TelegramMediaFile)?.isVoice == true ? .voice : .music), self.caption(caption, depth: next)])
        case let .document(id, caption):
            let name = (self.environment.media[id] as? TelegramMediaFile)?.fileName
            text = self.join([name.flatMap { $0.isEmpty ? nil : self.text($0) } ?? self.label(.file), self.caption(caption, depth: next)])
        case let .map(_, _, _, _, caption): text = self.join([self.label(.location), self.caption(caption, depth: next)])
        case let .webEmbed(url, _, _, caption, _, _, _):
            let captionText = self.caption(caption, depth: next)
            if captionText.length > 0 {
                text = captionText
            } else {
                let urlText = trimPreview(url.map(self.text) ?? NSAttributedString())
                text = urlText.length > 0 ? urlText : self.label(.embeddedContent)
            }
        case let .postEmbed(url, _, _, author, _, values, caption):
            let body = self.join([self.blocks(values, depth: next), self.caption(caption, depth: next)])
            text = body.length > 0 ? body : self.text(author.isEmpty ? url : author)
        case let .channelBanner(channel):
            let title = trimPreview(channel.map { self.text($0.title) } ?? NSAttributedString())
            text = title.length > 0 ? title : self.label(.channel)
        case let .relatedArticles(title, articles):
            var values = [self.rich(title, depth: next)]
            for article in articles {
                guard self.enter(next), self.join(values).string.count <= 200 else { break }
                values.append(self.text(article.title.flatMap { $0.isEmpty ? nil : $0 } ?? article.url))
            }
            text = self.join(values)
        case let .buttonRow(_, buttons):
            var values: [NSAttributedString] = []
            for button in buttons {
                guard !self.exhausted, self.join(values).string.count <= 200 else { break }
                values.append(self.rich(button.text, depth: next))
            }
            text = self.join(values)
        case let .list(items, _):
            var values: [NSAttributedString] = []
            for item in items {
                guard self.enter(next), self.join(values).string.count <= 200 else { break }
                let body: NSAttributedString
                let number: String?
                let checked: Bool?
                switch item {
                case .unknown: continue
                case let .text(value, num, check):
                    body = self.rich(value, depth: next + 1); number = num; checked = check
                case let .blocks(blocks, num, check):
                    body = self.blocks(blocks, depth: next + 1); number = num; checked = check
                }
                let prefix: NSAttributedString
                if let checked { prefix = self.text(checked ? "☑︎" : "☐") }
                else if let number, !number.isEmpty { prefix = self.text(number + ".") }
                else { prefix = NSAttributedString() }
                values.append(self.join([prefix, body]))
            }
            text = self.join(values)
        case let .collage(items, caption), let .slideshow(items, caption):
            let captionText = self.caption(caption, depth: next)
            if captionText.length != 0 { return Fragment(text: captionText) }
            var children: [NSAttributedString] = []
            var photos: Int32 = 0
            var videos: Int32 = 0
            var mediaOnly = true
            var childLength = 0
            for item in items {
                guard !self.exhausted else { break }
                let child = self.block(item, depth: next)
                photos += child.photos; videos += child.videos
                if child.text.length != 0 {
                    mediaOnly = mediaOnly && child.mediaOnly
                    if childLength <= 200 {
                        children.append(child.text)
                        childLength += child.text.string.count + 1
                    }
                }
            }
            if mediaOnly, photos + videos > 0 {
                var labels: [String] = []
                if photos > 0 { labels.append(self.environment.label(photos == 1 || self.exhausted ? .photo : .photos(photos))) }
                if videos > 0 { labels.append(self.environment.label(videos == 1 || self.exhausted ? .video : .videos(videos))) }
                return Fragment(text: NSAttributedString(string: labels.joined(separator: ", ")), photos: photos, videos: videos, mediaOnly: true)
            }
            text = self.join(children)
        }
        return Fragment(text: text)
    }
}

func buildInstantPagePreview(blocks: [InstantPageBlock], environment: InstantPagePreviewEnvironment) -> NSAttributedString {
    let builder = InstantPagePreviewBuilder(environment: environment)
    var text = trimPreview(builder.blocks(blocks, depth: 0))
    if text.length == 0 { text = trimPreview(builder.thinkingFallback()) }
    return clipInstantPagePreview(text, truncated: builder.exhausted)
}

public func styleInstantPagePreview(_ text: NSAttributedString, font: UIFont, italicFont: UIFont, textColor: UIColor) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: text)
    let range = NSRange(location: 0, length: result.length)
    result.addAttributes([.font: font, .foregroundColor: textColor], range: range)
    text.enumerateAttribute(instantPagePreviewItalic, in: range) { value, range, _ in
        if value != nil { result.addAttribute(.font, value: italicFont, range: range) }
    }
    return result
}

public func instantPagePreviewPlainText(_ text: NSAttributedString) -> String {
    let result = NSMutableAttributedString(attributedString: text)
    text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: .reverse) { attributes, range, _ in
        if let fallback = attributes[instantPagePreviewIconFallback] as? String {
            // Adjacent identical icons may coalesce into a single attribute run.
            let count = text.attributedSubstring(from: range).string.filter { $0 == "\u{fffc}" }.count
            result.replaceCharacters(in: range, with: String(repeating: fallback, count: count))
        } else if (attributes[instantPagePreviewCustomEmoji] != nil || attributes[ChatTextInputAttributes.customEmoji] != nil), text.attributedSubstring(from: range).string == "\u{fffc}" {
            result.replaceCharacters(in: range, with: "�")
        }
    }
    return clipInstantPagePreview(result).string
}
