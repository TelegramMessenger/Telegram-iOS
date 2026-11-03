import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
import RichTextEditorUIKit

/// Builders for content that reaches the composer only when EDITING a rich message (media with
/// captions, formulas, button rows, inline pills, mentions, dates, custom emoji), which the composer
/// cannot author itself. Assets never load offline: a medium is an id-only `TelegramMediaImage` and a
/// custom emoji's file carries no data, so these exercise the editing logic, not the pixels.
///
/// `installFormulaRenderer` stands in for the chat's `chatInputFormulaRenderResult` (TelegramUI,
/// which the harness cannot link): a plain image with baseline metrics, which is all the engine
/// needs to turn a formula run into ONE attachment character, as it does in the app.
enum HarnessEdited {
    static func run(_ text: String, _ configure: (inout ChatInputInlineAttributes) -> Void = { _ in }) -> ChatInputRun {
        var attributes = ChatInputInlineAttributes()
        configure(&attributes)
        return ChatInputRun(text: text, attributes: attributes)
    }

    static func paragraph(_ runs: [ChatInputRun]) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: nil, runs: runs))
    }

    static func image(_ id: Int64) -> TelegramMediaImage {
        return TelegramMediaImage(imageId: EngineMedia.Id(namespace: 0, id: id), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
    }

    static func audioFile(_ id: Int64) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: id), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/mpeg", size: nil, attributes: [.Audio(isVoice: false, duration: 10, title: "Song", performer: "Band", waveform: nil)], alternativeRepresentations: [])
    }

    static func media(_ id: Int64 = 1, caption: String) -> ChatInputBlock {
        return .media(ChatInputMedia(media: self.image(id), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0), caption: caption.isEmpty ? [] : [ChatInputRun(text: caption)]))
    }

    static func audio(_ id: Int64 = 2) -> ChatInputBlock {
        return .media(ChatInputMedia(media: self.audioFile(id), kind: .audio, naturalSize: ChatInputSize(width: 300.0, height: 44.0)))
    }

    static func formula(_ latex: String) -> ChatInputRun {
        return self.run(latex) { $0.formula = latex }
    }

    static func button(_ label: String) -> ChatInputButton {
        return ChatInputButton(label: [ChatInputRun(text: label)], action: .url(label.lowercased()))
    }

    static func pill(_ label: String) -> ChatInputRun {
        return self.run("\u{FFFC}") { $0.entity = .button(self.button(label)) }
    }

    static func buttonRow(_ labels: [String]) -> ChatInputBlock {
        return .buttonRow(ChatInputButtonRow(buttons: labels.map(self.button)))
    }

    static func mention(_ text: String, _ peer: Int64 = 777) -> ChatInputRun {
        return self.run(text) { $0.entity = .mention(EnginePeer.Id(peer)) }
    }

    static func date(_ text: String, _ timestamp: Int32 = 1_800_000_000) -> ChatInputRun {
        return self.run(text) { $0.entity = .date(timestamp) }
    }

    static func url(_ text: String, _ url: String = "https://telegram.org") -> ChatInputRun {
        return self.run(text) { $0.entity = .url(url) }
    }

    static func emojiFile(_ id: Int64) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])
    }

    /// A custom emoji as an edited message delivers it: its alt emoji as the run text.
    static func emoji(_ alt: String = "😀", _ id: Int64 = 5_000_000_001) -> ChatInputRun {
        return self.run(alt) { $0.entity = .customEmoji(fileId: id, file: self.emojiFile(id), enableAnimation: true) }
    }

    static func installFormulaRenderer(on host: HarnessPanelHost) {
        host.panel.formulaRenderer = { context in
            let size = CGSize(width: 12.0 + CGFloat(context.latex.count) * 6.0, height: 16.0)
            let image = UIGraphicsImageRenderer(size: size).image { renderer in
                context.textColor.setFill()
                renderer.fill(CGRect(origin: .zero, size: size).insetBy(dx: 1.0, dy: 1.0))
            }
            return RichTextFormulaRenderResult(image: image, size: size, ascent: 12.0, descent: 4.0)
        }
    }

    /// Every media block at any depth (quotes, details), counted.
    static func mediaCount(_ content: ChatInputContent) -> Int {
        return content.blocks.reduce(0) { count, block in
            switch block {
            case .media: return count + 1
            case let .blockQuote(quote): return count + self.mediaCount(quote.content)
            case let .details(details): return count + self.mediaCount(details.content)
            default: return count
            }
        }
    }

    /// A dump that shows what `FuzzModel.describe` hides: each run's entity kind and formula.
    static func describe(_ content: ChatInputContent, merging: Bool = true) -> String {
        func runs(_ runs: [ChatInputRun]) -> String {
            return (merging ? FuzzModel.merged(runs) : runs.filter { !$0.text.isEmpty }).map { run -> String in
                var tags: [String] = []
                let a = run.attributes
                if a.bold { tags.append("b") }
                if a.italic { tags.append("i") }
                if a.monospace { tags.append("m") }
                if a.spoiler { tags.append("sp") }
                if a.strikethrough { tags.append("s") }
                if a.underline { tags.append("u") }
                if let formula = a.formula { tags.append("f=\(fuzzEscaped(formula))") }
                switch a.entity {
                case let .mention(peer)?: tags.append("@\(peer.toInt64())")
                case let .date(t)?: tags.append("date=\(t)")
                case let .url(u)?: tags.append("url=\(u)")
                case let .customEmoji(fileId, file, _)?: tags.append("emoji=\(fileId)\(file == nil ? "/nofile" : "")")
                case let .button(b)?: tags.append("btn=\(b.label.map(\.text).joined())")
                case nil: break
                }
                return (tags.isEmpty ? "" : "[" + tags.joined(separator: ",") + "]") + fuzzEscaped(run.text)
            }.joined(separator: "+")
        }
        return content.blocks.map { block -> String in
            switch block {
            case let .paragraph(p): return "[p \(p.style) \(runs(p.runs))]"
            case let .media(m): return "[media \(m.kind) x\(m.items.count) cap=\(runs(m.caption))]"
            case let .buttonRow(r): return "[row \(r.buttons.map { $0.label.map(\.text).joined() }.joined(separator: "|"))]"
            case let .blockQuote(q): return "[quote \(self.describe(q.content, merging: merging)) author=\(runs(q.author))]"
            case let .details(d): return "[details title=\(runs(d.title)) \(self.describe(d.content, merging: merging))]"
            case let .pullQuote(q): return "[pull \(runs(q.runs)) author=\(runs(q.author))]"
            case let .code(c): return "[code \(runs(c.runs))]"
            case let .table(t): return "[table " + t.rows.map { "(" + $0.cells.map { runs($0.runs) }.joined(separator: " | ") + ")" }.joined(separator: " ") + "]"
            }
        }.joined(separator: " ")
    }
}
